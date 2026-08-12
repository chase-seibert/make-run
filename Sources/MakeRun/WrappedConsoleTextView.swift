import AppKit
import SwiftUI

struct WrappedConsoleTextView: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ConsoleScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.setAccessibilityLabel("Console output")

        scrollView.documentView = textView
        context.coordinator.fontSize = fontSize
        textView.textStorage?.setAttributedString(attributed(text))
        scrollView.requestInitialScrollToBottom()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let visibleRect = scrollView.contentView.documentVisibleRect
        let wasNearBottom = visibleRect.maxY >= textView.bounds.maxY - 28
        let oldSelection = textView.selectedRanges
        let fontChanged = context.coordinator.fontSize != fontSize

        if fontChanged {
            context.coordinator.fontSize = fontSize
            textView.textStorage?.setAttributedString(attributed(text))
        } else if textView.string != text {
            if text.hasPrefix(textView.string), let storage = textView.textStorage {
                let suffix = String(text.dropFirst(textView.string.count))
                storage.append(attributed(suffix))
            } else {
                textView.textStorage?.setAttributedString(attributed(text))
            }
        }

        let maximumLocation = (textView.string as NSString).length
        let validSelection = oldSelection.compactMap { value -> NSValue? in
            var range = value.rangeValue
            guard range.location <= maximumLocation else { return nil }
            range.length = min(range.length, maximumLocation - range.location)
            return NSValue(range: range)
        }
        if !validSelection.isEmpty { textView.selectedRanges = validSelection }

        if let consoleScrollView = scrollView as? ConsoleScrollView,
           consoleScrollView.isInitialScrollPending {
            consoleScrollView.requestInitialScrollToBottom()
        } else if wasNearBottom || maximumLocation == 0 {
            textView.scrollRangeToVisible(NSRange(location: maximumLocation, length: 0))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var fontSize: CGFloat = 13
    }

    private func attributed(_ value: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1
        return NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraph,
            ]
        )
    }
}

final class ConsoleScrollView: NSScrollView {
    private(set) var isInitialScrollPending = true
    private var isInitialScrollScheduled = false

    override func layout() {
        super.layout()
        requestInitialScrollToBottom()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestInitialScrollToBottom()
    }

    func requestInitialScrollToBottom() {
        guard isInitialScrollPending, !isInitialScrollScheduled else { return }
        isInitialScrollScheduled = true
        perform(#selector(performInitialScrollToBottom), with: nil, afterDelay: 0)
    }

    @objc func performInitialScrollToBottom() {
        isInitialScrollScheduled = false
        guard isInitialScrollPending,
              window != nil,
              contentView.bounds.width > 0,
              contentView.bounds.height > 0,
              let textView = documentView as? NSTextView,
              let textContainer = textView.textContainer else {
            return
        }

        layoutSubtreeIfNeeded()
        textView.layoutManager?.ensureLayout(for: textContainer)
        let end = (textView.string as NSString).length
        textView.scrollRangeToVisible(NSRange(location: end, length: 0))

        // scrollRangeToVisible can run before the clip view adopts its final
        // SwiftUI size. Pin the document origin as a second, geometry-based
        // guarantee after text layout has completed.
        let bottomY = max(0, textView.bounds.maxY - contentView.bounds.height)
        contentView.scroll(to: NSPoint(x: 0, y: bottomY))
        reflectScrolledClipView(contentView)
        isInitialScrollPending = false
    }
}
