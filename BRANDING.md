# Kinetic - Branding Guidelines

## App Icons

The app currently has placeholder icons. You'll need to create custom icons for both iPhone and Apple Watch.

### Requirements

**iPhone App Icon**
- Location: `iphone_sensor_app_no_claude/Assets.xcassets/AppIcon.appiconset/`
- Size: 1024x1024px PNG
- Style: iOS app icon design (rounded square will be applied automatically)
- Variants: Light, dark, and tinted appearances

**Apple Watch App Icon**
- Location: `Sensor Watch App/Assets.xcassets/AppIcon.appiconset/`
- Size: 1024x1024px PNG
- Style: watchOS app icon (circular crop will be applied automatically)

### Design Suggestions

For the "Kinetic" brand, consider:
- **Motion-focused**: Abstract representation of movement, waves, or acceleration
- **Minimal**: Clean, modern aesthetic (think Stripe, Audible level of simplicity)
- **Color palette**: Single bold color or gradient
- **Avoid**: Literal sensors, charts, graphs, or overly technical imagery

### Tools

- **Figma/Sketch**: Design the icon
- **SF Symbols**: Optional - use Apple's system symbols as inspiration
- **Icon templates**: Search for "iOS app icon template" for proper guidelines

### Implementation

1. Design 1024x1024px PNG
2. Drag into Xcode Assets.xcassets
3. Xcode will generate all required sizes automatically

## Color Scheme

Current accent color: Default blue

Consider updating `AccentColor.colorset` to match your icon's primary color for brand consistency.

## Display Names

- **iPhone App**: Kinetic
- **Apple Watch App**: Kinetic
- **Bundle ID**: com.andrew.kinetic

All branding has been standardized to "Kinetic" throughout the project.
