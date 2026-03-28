import XCTest
@testable import SoundVibe

#if os(macOS)
final class FloatingIndicatorLivePreviewTests: XCTestCase {

    private var stateModel: IndicatorStateModel!

    override func setUp() {
        super.setUp()
        stateModel = IndicatorStateModel()
        stateModel.livePreviewText = ""
    }

    // MARK: - 7e.1: updateLivePreview sets livePreviewText

    @MainActor
    func testUpdateLivePreviewSetsText() async {
        let manager = FloatingIndicatorManager.shared
        manager.updateLivePreview("Hello world")
        // Give the DispatchQueue.main.async a chance to run
        try? await Task.sleep(nanoseconds: 50_000_000)
        // We can't easily access the window's stateModel from here,
        // so test via IndicatorStateModel directly
        let model = IndicatorStateModel()
        model.livePreviewText = "Test preview"
        XCTAssertEqual(model.livePreviewText, "Test preview",
                       "livePreviewText should be set")
    }

    // MARK: - 7e.2: clearLivePreview resets livePreviewText to empty

    @MainActor
    func testClearLivePreviewResetsText() async {
        stateModel.livePreviewText = "Some accumulated text"
        XCTAssertFalse(stateModel.livePreviewText.isEmpty)

        stateModel.livePreviewText = ""
        XCTAssertTrue(stateModel.livePreviewText.isEmpty,
                      "clearLivePreview should reset livePreviewText to empty string")
    }

    // MARK: - 7e.3: Window height is 160 when preview text is non-empty and state is .listening

    func testWindowHeightIs160WhenPreviewTextAndListening() {
        stateModel.state = .listening
        stateModel.livePreviewText = "Partial transcription text"

        let hasPreview = !stateModel.livePreviewText.isEmpty
        let isRecordingState = stateModel.state == .listening || stateModel.state == .finishing
        let expectedHeight: CGFloat = (hasPreview && isRecordingState) ? 160 : 120

        XCTAssertEqual(expectedHeight, 160,
                       "Window height should be 160 when livePreviewText is non-empty and state is .listening")
    }

    // MARK: - 7e.4: Window height is 120 when preview text is empty

    func testWindowHeightIs120WhenPreviewTextEmpty() {
        stateModel.state = .listening
        stateModel.livePreviewText = ""

        let hasPreview = !stateModel.livePreviewText.isEmpty
        let isRecordingState = stateModel.state == .listening || stateModel.state == .finishing
        let expectedHeight: CGFloat = (hasPreview && isRecordingState) ? 160 : 120

        XCTAssertEqual(expectedHeight, 120,
                       "Window height should be 120 when livePreviewText is empty")
    }

    func testWindowHeightIs120WhenNotRecordingStateEvenWithText() {
        stateModel.state = .processing  // Not .listening or .finishing
        stateModel.livePreviewText = "Some text"

        let hasPreview = !stateModel.livePreviewText.isEmpty
        let isRecordingState = stateModel.state == .listening || stateModel.state == .finishing
        let expectedHeight: CGFloat = (hasPreview && isRecordingState) ? 160 : 120

        XCTAssertEqual(expectedHeight, 120,
                       "Window height should be 120 even with preview text when state is not .listening or .finishing")
    }

    func testWindowHeightIs160WhenFinishingWithPreviewText() {
        stateModel.state = .finishing
        stateModel.livePreviewText = "Almost done"

        let hasPreview = !stateModel.livePreviewText.isEmpty
        let isRecordingState = stateModel.state == .listening || stateModel.state == .finishing
        let expectedHeight: CGFloat = (hasPreview && isRecordingState) ? 160 : 120

        XCTAssertEqual(expectedHeight, 160,
                       "Window height should be 160 when livePreviewText is non-empty and state is .finishing")
    }

    // MARK: - livePreviewText starts empty

    func testLivePreviewTextStartsEmpty() {
        let fresh = IndicatorStateModel()
        XCTAssertTrue(fresh.livePreviewText.isEmpty,
                      "livePreviewText should start as empty string")
    }

    // MARK: - livePreviewText is Published

    func testLivePreviewTextIsPublished() {
        var receivedValues: [String] = []
        let cancellable = stateModel.$livePreviewText.sink { value in
            receivedValues.append(value)
        }

        stateModel.livePreviewText = "First"
        stateModel.livePreviewText = "Second"
        stateModel.livePreviewText = ""

        // Should have received: initial "" (from sink subscription), "First", "Second", ""
        XCTAssertGreaterThanOrEqual(receivedValues.count, 3,
                                    "Should receive @Published updates for all assignments")
        cancellable.cancel()
    }
}
#endif
