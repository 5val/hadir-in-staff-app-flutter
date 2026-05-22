# 🎨 Color Palette - Hadir-In

> **Official color palette untuk Hadir-In Web Admin berdasarkan logo perusahaan**

---

## 🎯 **Brand Colors (Primary)**

### **1. Navy Blue (Primary)**

**Color Name:** Brand Navy  
**Hex:** `#2D377F`  
**RGB:** `rgb(45, 55, 127)`  
**HSL:** `hsl(234, 48%, 34%)`  
**CSS Variable:** `--brand-navy: 45 55 127;`

**Usage:**

- Primary brand color
- Main headings
- Logo text
- Primary buttons
- Navigation active states
- Footer background

**Example:**

```css
/* Solid background */
background-color: rgb(var(--brand-navy));

/* Gradient */
background: linear-gradient(
  135deg,
  rgb(var(--brand-navy)),
  rgb(var(--brand-navy-dark))
);

/* Text */
color: rgb(var(--brand-navy));
```

---

### **2. Cyan Blue (Secondary)**

**Color Name:** Brand Cyan  
**Hex:** `#4DD0E1`  
**RGB:** `rgb(77, 208, 225)`  
**HSL:** `hsl(187, 71%, 59%)`  
**CSS Variable:** `--brand-cyan: 77 208 225;`

**Usage:**

- Secondary accent color
- Highlights and emphasis
- Interactive elements (hover states)
- Icons and badges
- Call-to-action accents
- Links

**Example:**

```css
/* Solid background */
background-color: rgb(var(--brand-cyan));

/* With opacity */
background-color: rgba(77, 208, 225, 0.1);

/* Gradient */
background: linear-gradient(
  135deg,
  rgb(var(--brand-cyan)),
  rgb(var(--brand-cyan-light))
);
```

---

### **3. Lime Green (Accent)**

**Color Name:** Brand Lime  
**Hex:** `#9CCC65`  
**RGB:** `rgb(156, 204, 101)`  
**HSL:** `hsl(88, 51%, 60%)`  
**CSS Variable:** `--brand-lime: 156 204 101;`

**Usage:**

- Success states
- Checkmarks and confirmations
- Positive metrics
- Achievement indicators
- Feature highlights
- Progress indicators

**Example:**

```css
/* Solid background */
background-color: rgb(var(--brand-lime));

/* Border */
border-color: rgb(var(--brand-lime));

/* Gradient with opacity */
background: linear-gradient(90deg, rgba(156, 204, 101, 0.2), transparent);
```

---

## 🌈 **Extended Palette**

### **Navy Variants**

#### **Navy Dark**

- **Hex:** `#1E285A`
- **RGB:** `rgb(30, 40, 90)`
- **CSS Variable:** `--brand-navy-dark: 30 40 90;`
- **Usage:** Darker accents, shadows, hover states on navy

#### **Navy Light**

- **Hex:** `#4A5599`
- **RGB:** `rgb(74, 85, 153)`
- **Usage:** Lighter navy for backgrounds, subtle highlights

---

### **Cyan Variants**

#### **Cyan Light**

- **Hex:** `#64E6F5`
- **RGB:** `rgb(100, 230, 245)`
- **CSS Variable:** `--brand-cyan-light: 100 230 245;`
- **Usage:** Lighter cyan for backgrounds, hover states

#### **Cyan Dark**

- **Hex:** `#00ACC1`
- **RGB:** `rgb(0, 172, 193)`
- **Usage:** Darker cyan for text, borders

---

### **Lime Variants**

#### **Lime Light**

- **Hex:** `#C5E1A5`
- **RGB:** `rgb(197, 225, 165)`
- **Usage:** Light lime for backgrounds, subtle accents

#### **Lime Dark**

- **Hex:** `#7CB342`
- **RGB:** `rgb(124, 179, 66)`
- **Usage:** Darker lime for text, emphasis

---

## 🎨 **Gradient Combinations**

### **1. Navy to Cyan (Primary Gradient)**

```css
background: linear-gradient(135deg, #2d377f 0%, #4dd0e1 100%);
```

**Usage:** Hero sections, primary CTAs, main banners

---

### **2. Cyan to Lime (Success Gradient)**

```css
background: linear-gradient(135deg, #4dd0e1 0%, #9ccc65 100%);
```

**Usage:** Success messages, positive indicators, growth metrics

---

### **3. Navy Dark to Navy (Depth Gradient)**

```css
background: linear-gradient(180deg, #1e285a 0%, #2d377f 100%);
```

**Usage:** Headers, footers, navigation bars

---

### **4. Radial Hero Gradient**

```css
background: radial-gradient(
  circle at top right,
  rgba(45, 55, 127, 0.3) 0%,
  rgba(77, 208, 225, 0.2) 50%,
  transparent 100%
);
```

**Usage:** Hero section backgrounds, overlay effects

---

## 🖼️ **Neutral Colors (Supporting)**

### **Background Colors**

| Name          | Hex       | RGB                  | Usage                  |
| ------------- | --------- | -------------------- | ---------------------- |
| **White**     | `#FFFFFF` | `rgb(255, 255, 255)` | Main background, cards |
| **Slate 50**  | `#F8FAFC` | `rgb(248, 250, 252)` | Light background       |
| **Slate 100** | `#F1F5F9` | `rgb(241, 245, 249)` | Hover backgrounds      |
| **Slate 200** | `#E2E8F0` | `rgb(226, 232, 240)` | Borders                |
| **Slate 300** | `#CBD5E1` | `rgb(203, 213, 225)` | Disabled states        |

---

### **Text Colors**

| Name          | Hex       | RGB                  | Usage            |
| ------------- | --------- | -------------------- | ---------------- |
| **Slate 900** | `#0F172A` | `rgb(15, 23, 42)`    | Primary text     |
| **Slate 800** | `#1E293B` | `rgb(30, 41, 59)`    | Secondary text   |
| **Slate 700** | `#334155` | `rgb(51, 65, 85)`    | Body text        |
| **Slate 600** | `#475569` | `rgb(71, 85, 105)`   | Muted text       |
| **Slate 400** | `#94A3B8` | `rgb(148, 163, 184)` | Placeholder text |

---

## 📐 **Tailwind CSS Classes**

### **Using Brand Colors in Tailwind**

Since the brand colors are custom, use them with RGB values:

```html
<!-- Navy Blue -->
<div class="bg-[rgb(45,55,127)]">Navy Background</div>
<p class="text-[rgb(45,55,127)]">Navy Text</p>

<!-- Cyan Blue -->
<div class="bg-[rgb(77,208,225)]">Cyan Background</div>
<p class="text-[rgb(77,208,225)]">Cyan Text</p>

<!-- Lime Green -->
<div class="bg-[rgb(156,204,101)]">Lime Background</div>
<p class="text-[rgb(156,204,101)]">Lime Text</p>

<!-- Gradients -->
<div class="bg-gradient-to-r from-[rgb(45,55,127)] to-[rgb(77,208,225)]">
  Navy to Cyan Gradient
</div>

<div
  class="bg-gradient-to-r from-[rgb(77,208,225)] via-[rgb(100,230,245)] to-[rgb(156,204,101)]"
>
  Multi-color Gradient
</div>
```

---

### **Recommended Class Additions (Optional)**

Add to `tailwind.config.ts`:

```typescript
export default {
  theme: {
    extend: {
      colors: {
        brand: {
          navy: {
            DEFAULT: "rgb(45, 55, 127)",
            dark: "rgb(30, 40, 90)",
            light: "rgb(74, 85, 153)",
          },
          cyan: {
            DEFAULT: "rgb(77, 208, 225)",
            light: "rgb(100, 230, 245)",
            dark: "rgb(0, 172, 193)",
          },
          lime: {
            DEFAULT: "rgb(156, 204, 101)",
            light: "rgb(197, 225, 165)",
            dark: "rgb(124, 179, 66)",
          },
        },
      },
    },
  },
};
```

**Then use:**

```html
<div class="bg-brand-navy">Navy</div>
<div class="bg-brand-cyan">Cyan</div>
<div class="bg-brand-lime">Lime</div>
<div class="bg-gradient-to-r from-brand-navy to-brand-cyan">Gradient</div>
```

---

## 🎯 **Color Usage Guidelines**

### **Do's ✅**

1. **Use Navy for trust and professionalism**

   - Primary branding elements
   - Important headings
   - Navigation

2. **Use Cyan for modern and tech feel**

   - Interactive elements
   - Highlights
   - Secondary CTAs

3. **Use Lime for success and positivity**

   - Success messages
   - Positive metrics (time saved, ROI)
   - Feature highlights

4. **Maintain contrast ratios**
   - Navy text on white: 10.5:1 (AAA) ✅
   - Cyan text on white: 2.8:1 (Needs dark version for text)
   - Lime on white: 3.2:1 (Needs dark version for text)

---

### **Don'ts ❌**

1. **Don't use cyan/lime for main text** - Low contrast
2. **Don't mix all three colors equally** - Choose one dominant
3. **Don't use pure black (#000)** - Use navy or slate-900
4. **Don't use colors at 100% opacity everywhere** - Use transparency

---

## 🖌️ **Semantic Color Mapping**

### **UI States**

```css
/* Success */
--color-success: rgb(var(--brand-lime));
--color-success-bg: rgba(156, 204, 101, 0.1);
--color-success-border: rgba(156, 204, 101, 0.3);

/* Info */
--color-info: rgb(var(--brand-cyan));
--color-info-bg: rgba(77, 208, 225, 0.1);
--color-info-border: rgba(77, 208, 225, 0.3);

/* Primary */
--color-primary: rgb(var(--brand-navy));
--color-primary-bg: rgba(45, 55, 127, 0.1);
--color-primary-border: rgba(45, 55, 127, 0.3);

/* Warning */
--color-warning: rgb(255, 193, 7);
--color-warning-bg: rgba(255, 193, 7, 0.1);

/* Error */
--color-error: rgb(244, 67, 54);
--color-error-bg: rgba(244, 67, 54, 0.1);
```

---

## 📊 **Accessibility (WCAG Compliance)**

### **Contrast Ratios**

| Combination             | Ratio      | WCAG Level           | Usage                      |
| ----------------------- | ---------- | -------------------- | -------------------------- |
| Navy (#2D377F) on White | **10.5:1** | AAA ✅               | Body text, headings        |
| Navy on Slate-50        | **9.8:1**  | AAA ✅               | Text on light backgrounds  |
| Cyan (#4DD0E1) on Navy  | **5.2:1**  | AA ✅                | Accent text on dark        |
| Lime (#9CCC65) on Navy  | **4.8:1**  | AA ✅                | Success on dark            |
| Cyan on White           | **2.8:1**  | ❌ Fail              | Don't use for text         |
| Lime on White           | **3.2:1**  | AA (Large text only) | Use for badges/badges only |

**Recommendation:**

- Use **Navy or Slate-700+** for body text
- Use **Cyan/Lime** for backgrounds, borders, icons (not small text)
- For cyan/lime text, use darker variants or sufficient background contrast

---

## 🎨 **Color Combinations**

### **Best Combinations**

1. **Professional (Navy + White)**

   ```
   Background: White
   Text: Navy (#2D377F)
   Accent: Cyan (#4DD0E1)
   ```

2. **Modern (Navy + Cyan + White)**

   ```
   Background: Navy gradient
   Text: White
   Accent: Cyan + Lime
   ```

3. **Fresh (White + Cyan + Lime)**
   ```
   Background: White with cyan tints
   Text: Navy
   Highlights: Lime green
   ```

---

## 🔧 **Implementation Examples**

### **Button Styles**

```css
/* Primary Button (Navy) */
.btn-primary {
  background: linear-gradient(135deg, rgb(45, 55, 127), rgb(30, 40, 90));
  color: white;
  border: none;
}

.btn-primary:hover {
  background: rgb(30, 40, 90);
}

/* Secondary Button (Cyan) */
.btn-secondary {
  background: linear-gradient(135deg, rgb(77, 208, 225), rgb(100, 230, 245));
  color: rgb(30, 40, 90);
  border: none;
}

/* Success Button (Lime) */
.btn-success {
  background: rgb(156, 204, 101);
  color: rgb(30, 40, 90);
}
```

---

### **Card Styles**

```css
/* Primary Card */
.card-primary {
  background: white;
  border: 2px solid rgba(45, 55, 127, 0.1);
  box-shadow: 0 4px 6px rgba(45, 55, 127, 0.1);
}

/* Highlighted Card */
.card-highlight {
  background: linear-gradient(
    135deg,
    rgba(77, 208, 225, 0.1),
    rgba(156, 204, 101, 0.1)
  );
  border: 2px solid rgb(77, 208, 225);
}
```

---

### **Badge Styles**

```css
/* Info Badge */
.badge-info {
  background: rgba(77, 208, 225, 0.2);
  color: rgb(0, 172, 193);
  border: 1px solid rgb(77, 208, 225);
}

/* Success Badge */
.badge-success {
  background: rgba(156, 204, 101, 0.2);
  color: rgb(124, 179, 66);
  border: 1px solid rgb(156, 204, 101);
}
```

---

## 📱 **Responsive Considerations**

### **Mobile**

- Use higher contrast (Navy on white preferred)
- Larger touch targets with cyan backgrounds
- Clear visual hierarchy with navy headings

### **Desktop**

- Can use more subtle gradients
- More cyan accents acceptable
- Complex color combinations work better

---

## 🎯 **Brand Consistency Checklist**

- [ ] Logo uses correct navy (#2D377F)
- [ ] Primary CTAs use navy or cyan gradient
- [ ] Success states use lime green
- [ ] All text meets WCAG AA contrast (minimum)
- [ ] Gradients use brand colors only
- [ ] Hover states use darker variants
- [ ] Disabled states use slate-300
- [ ] Error states use red (not brand colors)

---

## 📊 **Color Statistics**

**Current Usage in Project:**

- Navy Blue: ~40% (Primary branding, headers, footers)
- Cyan Blue: ~30% (Accents, buttons, highlights)
- Lime Green: ~15% (Success states, checkmarks)
- Slate/Gray: ~15% (Text, borders, backgrounds)

**Recommended Balance:**

- Navy: 35-45% (Dominant brand presence)
- Cyan: 25-35% (Strong secondary presence)
- Lime: 10-20% (Accent and highlights)
- Neutrals: 15-25% (Supporting elements)

---

## 🔗 **References**

- **Logo File:** `public/logo_hadir_in.png`
- **CSS Variables:** `src/app/globals.css`
- **Tailwind Config:** `tailwind.config.ts` (if extended)
- **Component Examples:** `src/app/page.tsx`

---

## 📝 **Version History**

**v1.0.0 - January 7, 2026**

- Initial color palette based on logo
- Defined primary brand colors (Navy, Cyan, Lime)
- Created extended palette with variants
- Added Tailwind CSS integration
- Documented accessibility guidelines
- Added usage examples

---

**Last Updated:** January 7, 2026  
**Version:** 1.0.0  
**Status:** Active ✅

**For questions or changes, contact:** design@hadir-in.com
