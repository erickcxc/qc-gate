# Music Asset QC Rubric

The standard every generated cover/thumbnail is judged against, by comparing the candidate
to the reference images in `references/` (the operator's mood board = the target aesthetic).
Tune this file to move the bar. The judge ([[qc-image.sh]]) scores each dimension 0-10.

## Pass conditions (ALL must hold)
- `overall` >= 7.0
- No dimension below 5.
- Zero **critical violations** (any critical violation is an automatic FAIL regardless of score).

## Dimensions (0-10 each)

1. **aesthetic_match** — Does the candidate look like it belongs in the same world as the
   reference images? Same visionary-cosmic family: deep cosmic base, dense starfield,
   particulate light, pointillist iridescent shimmer (Alex Grey / Android Jones / James R.
   Eads lineage). A generic 3D render, stock-photo look, or flat vector style fails this.
2. **composition** — Lone small human figure, back to camera, facing a vast central light.
   The builder-before-the-immense framing the references share.
3. **brand_thread** — The teal-cyan (#2DE2E6) neural-sphere reads as the central light source.
   Teal present as the signature accent. Logo rendered, not pasted/composited.
4. **craft** — Cinematic, premium, high-resolution feel. No artifacts, mangled anatomy,
   garbled shapes, muddy color, or AI-slop texture.
5. **mood_fidelity** — Conveys the intended vibe (mono-focus = cold/still/silver;
   prism-flow = euphoric/rainbow; epic = monumental/heroic) without breaking the shared DNA.

## Critical violations (any one = automatic FAIL)
- Any visible **text, words, letters, watermark, or signature** baked into the image
  (unless the asset is explicitly a titled thumbnail being judged for legibility).
- Any **em dash** or **emoji** rendered in the image.
- Looks like a **different brand / unrelated style** from the references (off-aesthetic).
- **Mangled human anatomy** or obvious generation artifacts in the focal subject.
- The figure or scene is **kitsch / cheesy** in a way none of the references are. Specifically
  for iridescent/rainbow vibes: a **symmetrical radial rainbow starburst**, oversaturated
  full-spectrum "rainbow-vomit," or a new-age-poster look is CHEESY = FAIL. The references
  carry color as **painterly, asymmetric, oil-slick / aurora / nebula** texture woven into a
  dark cosmic scene, never a clean symmetrical spectrum blast. When in doubt, judge it cheesy.

## Output contract
The judge returns JSON only:
```json
{
  "dimensions": {"aesthetic_match": 0, "composition": 0, "brand_thread": 0, "craft": 0, "mood_fidelity": 0},
  "overall": 0.0,
  "critical_violations": ["..."],
  "verdict": "PASS" | "FAIL",
  "reasons": "one tight paragraph: what matched, what missed, vs the references"
}
```
The gate ([[qc_gate.py]]) recomputes PASS/FAIL from the scores + violations; the model's own
`verdict` is advisory only. Code decides, not vibes.
