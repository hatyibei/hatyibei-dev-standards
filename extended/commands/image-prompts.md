---
allowed-tools: Read, Glob, Grep, WebSearch
description: Output image-generation prompts and storage paths tailored to a diagnostic type
argument-hint: diagnostic name (e.g., bigfive, mbti, disc)
---

For the specified diagnostic type, output the prompts to pass to the image-generation AI and the image storage destinations.

## Important Assumptions

- **The user performs the image generation (via Nanobanana2 etc.). Claude only provides prompts and storage paths.**
- Diagnostic content is authored by creators (not end users).
- Viral images = humor, distinctive characters, makes people want to share on SNS.

## Procedure

1. **Check diagnostic data**
   - Read the project's diagnostic definition files
   - Obtain the list of result types (personality types, etc.)
   - Verify the description and characteristics of each type

2. **Decide image variants**
   - Cover image (shown at the top of the diagnostic): 1 image
   - Result-type images (one per type): equal to the number of types
   - OGP / SNS share image: 1 image

3. **Prompt generation rules**
   - Center a humanoid or animal-type character
   - Visually express the personality traits of that type
   - Aim for the humor and individuality of MBTI 16-type diagnostics
   - Consistent art style (unify style within a single diagnostic)
   - Do not make faces resemble real people (Vertex AI safety standards)

4. **Output format**

```
## Image Generation Prompts: [diagnostic name]

### Recommended Art Style
- Style: [e.g., pop illustration / flat design / watercolor]
- Color palette: [e.g., pastel / vivid]
- Unifying element: [e.g., same pose across all types, differentiated by background color]

### Cover Image
- **Destination**: `/home/hatyibei/Image/[診断名]/cover.png`
- **Prompt**: ...
- **Size**: 1200x630px (also used for OGP)

### Per-type Images
#### Type 1: [type name]
- **Destination**: `/home/hatyibei/Image/[診断名]/type-[id].png`
- **In-project location**: `public/images/diagnoses/[診断名]/[id].png`
- **Traits**: [personality characteristics of this type]
- **Prompt**: ...

#### Type 2: [type name]
...(same pattern)
```

## Reference: Traits of Viral Images
- A relatable "that's so me" feeling that makes people want to share on SNS
- Type differences recognizable at a glance
- Visuals that convey meaning even without text
- High legibility on mobile
