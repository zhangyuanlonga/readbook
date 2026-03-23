# Mobile Adaptive Guidelines

## Scope

This project targets phones first and also supports tablet/large screens. Responsive behavior must be validated by logical viewport size (`dp`) and text scale, not by physical pixels only.

## Single Source Of Truth

- Use `AppLayout` and `AppSpacing` as the only responsive entry points.
- Keep breakpoint constants in `lib/app/layout/app_layout.dart`.
- Do not define new page-level breakpoint magic numbers.
- Mobile-first baseline: treat widths `<=360dp` as small phones.

## Required Rules

- Do not write direct width thresholds in page code like `width < 430` or `constraints.maxWidth >= 760`.
- Use `AppLayout` helpers instead (`widthBucketFor`, `isMediumUp`, `pageContentMaxWidth`, `dialogMaxWidth`).
- For fixed-looking widgets, prefer clamped width based on available space.
- For dialog/sheet width, always use `AppLayout.dialogMaxWidth(...)` or `AppLayout.pageContentMaxWidth(...)`.

## Test Matrix

### Phone (logical viewport + DPR)

- `360x800 @3.0`
- `390x844 @3.0`
- `412x915 @3.5`
- `414x921 @3.25`
- `427x924 @3.0`
- `480x1066 @3.0`
- landscape baseline: `640x360 @3.0`

### Tablet/Large

- `840x1180 @2.0`
- `1024x1366 @2.0`
- `1366x1024 @2.0`

### Text Scale

- `1.0`
- `1.3`
- `1.5`

## Required Smoke Coverage

- Shell navigation scaffold
- Bookshelf page
- Discover page
- Reader page / reading records
- Mine page
- Search page

## Delivery Checklist

- `flutter analyze` passes for changed files.
- Responsive matrix tests pass.
- No new layout overflow exceptions in matrix smoke tests.
