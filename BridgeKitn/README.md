# BridgeTeacherHandCompose (macOS)

A macOS tool to visualize bridge deals, add per-board notes, aggregate session PBN files, and export a high‑quality snapshot JPG for sharing or archiving.

![Screenshot Placeholder](Docs/screenshot.jpg)

## Features
- Visualizes four hands with suit‑grouped, overlapped cards using a custom `PlayingCardView`.
- Displays per‑seat HCP badges.
- Edits and saves per‑board notes as `Board X.notes.txt` in the session folder.
- Aggregates per‑deal `.pbn` fragments into a single session `.pbn` file (named after the session).
- Exports a snapshot JPG (`Board X.jpg`) via SwiftUI `ImageRenderer` and AppKit.
- Clean, felt‑style background with a simple "Record" action that saves notes and a snapshot together.

## Requirements
- macOS 13 or later
- Xcode 15 or later (SwiftUI with `ImageRenderer`)
- Platform: macOS only

## Getting Started
1. Clone this repository and open the Xcode project in Xcode.
2. Build and run the app on macOS.
3. Provide or select a session folder that contains per‑board `.pbn` files (for example: `Board 1.pbn`, `Board 2.pbn`, …).
4. Enter notes for the current board and click "Record" to:
   - Save notes to `Board X.notes.txt` inside the session folder.
   - Export a snapshot image to `Board X.jpg` inside the session folder.
   - Aggregate `.pbn` fragments into a session `.pbn` file written next to the session folder.

### Notes About Data Format
- Ranks are expected in descending order: `A,K,Q,J,T,9,...,2`.
- Suits are ordered Spades, Hearts, Diamonds, Clubs when displayed.
- The main view uses `DealDisplayData` to provide board metadata and per‑seat hands.

## Sample Data
A small sample session is included in `SampleSession/` with two PBN fragments (`Board 1.pbn`, `Board 2.pbn`).
You can point the app at this folder to test notes, aggregation, and snapshot export.

## Known Limitations
- macOS only; snapshot export uses AppKit (`NSBitmapImageRep`) for JPEG encoding.
- Notes are saved as plain text files adjacent to PBNs.
- The view expects a valid `sessionFolderURL` and `sessionName` to perform aggregation.

## Project Structure (high‑level)
- `DealDisplayPictureView.swift`: Main view for rendering the deal, notes, and actions (Record/Next Hand).
- `PlayingCardView.swift`: Renders individual playing cards.

## Roadmap (Ideas)
- Optional cross‑platform snapshot path using ImageIO (`CGImageDestination`).
- Simple status/toast feedback on successful snapshot/notes save.
- Sample session folder and screenshot in `Docs/` for easier onboarding.

## License
MIT — see [LICENSE](LICENSE) for details.

