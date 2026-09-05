# Artwork

`Resources/VoiceOrb.png` is the app's transparent orb artwork. The same static image is used for the menu-bar button and popover header. `scripts/make-icon.swift` scales it into an iconset; the build script compiles the macOS `.icns`. It does not change with microphone activity.

The artwork was created with Codex's built-in **imagegen** tool on 2026-09-05, using a user-supplied image of a luminous voice orb as a visual reference. The reference screenshot is not distributed. This is an independent project illustration, not an official OpenAI logo or a claim of affiliation. The generated asset is included under this repository's MIT license to the extent applicable.

## Generation prompt

> Use case: logo-brand. Asset type: production macOS app icon for independent open-source wake phrase companion Hey Voice. The attached image is a style reference, not an image to copy verbatim: a soft luminous white and periwinkle blue voice orb. Create ONE polished icon asset, square 1024x1024, true transparent background. Center a large perfectly round luminous orb occupying 82% of the canvas, with a crisp clean circular silhouette, pearl-white lower half, cool periwinkle and lavender upper half, soft cloudy internal movement and a subtle curved white sound ripple within the sphere. Keep it minimal, calm and readable at small sizes. Make the orb feel distinct and original but clearly inspired by the provided voice orb. No letters, no H, no words, no logos, no microphone glyph, no rounded-square tile, no black background, no mockup, no grid, no outside decorations, no strong surrounding glow. The only visible object is the complete orb, fully inside the canvas with even transparent margins.

The returned original is 1254 × 1254 pixels with alpha; the icon compiler produces the platform's required sizes up to 1024 × 1024 without removing transparency.
