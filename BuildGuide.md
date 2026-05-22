# E-COMMERCE SALES & PROFITABILITY DASHBOARD
## Complete Power BI Build Guide — Step by Step (Beginner Friendly)

---

## BEFORE YOU START — FILES IN THIS PACKAGE

| File | Purpose |
|---|---|
| `EcommerceDark_Theme.json` | Apply this first — sets all colors, fonts, shadows automatically |
| `All_DAX_Measures.dax` | All 40+ DAX formulas — copy-paste into Power BI |
| `BuildGuide.md` | This file — your full step-by-step mentor guide |

---

## COLOR PALETTE (EXACT HEX)

| Role | Color | HEX |
|---|---|---|
| Page background | Deep navy black | `#0D0F1A` |
| Visual card background | Dark slate | `#161928` |
| Card border | Subtle purple-grey | `#2A2D45` |
| Panel background | Slightly lighter dark | `#1A1D2E` |
| Revenue / Purple | Neon purple | `#A855F7` |
| Profit / Blue | Electric blue | `#3B82F6` |
| Warning / Gold | Amber | `#F59E0B` |
| Success / Green | Emerald | `#10B981` |
| Danger / Red | Coral red | `#EF4444` |
| Cyan accent | Cyan | `#06B6D4` |
| Orange accent | Orange | `#F97316` |
| Text primary | White | `#FFFFFF` |
| Text secondary | Cool grey | `#9CA3AF` |
| Text body | Light grey | `#D1D5DB` |
| Gridlines | Very dark purple-grey | `#1F2235` |

---

## FONT SYSTEM

| Element | Font | Size | Weight |
|---|---|---|---|
| KPI number (big value) | Segoe UI Black | 28–32pt | Black |
| KPI label above number | Segoe UI | 9pt | Regular |
| Chart titles | Segoe UI Semibold | 11pt | Semibold |
| Axis labels | Segoe UI | 9pt | Regular |
| Table data | Segoe UI | 9pt | Regular |
| Slicer text | Segoe UI | 10pt | Regular |
| Filter panel header | Segoe UI Semibold | 11pt | Semibold, yellow `#F59E0B` |
| Footer text | Segoe UI | 8pt | Regular, grey |

---

## PAGE SETUP

**Recommended canvas size: 1400 × 900 px**

Steps:
1. Open Power BI Desktop
2. Click `View` tab → `Page View` → `Actual Size`
3. Right-click on the report canvas → `Page Properties` (or in the `Format` pane on the right when nothing is selected)
4. Width: `1400` | Height: `900`
5. Background color: `#0D0F1A` | Transparency: `0%`
6. Wallpaper: same color `#0D0F1A`

---

## STEP 1 — APPLY THE THEME

1. Click `View` tab in the top ribbon
2. Click `Themes` dropdown → `Browse for themes`
3. Select `EcommerceDark_Theme.json` from this folder
4. Click Open → Power BI instantly applies dark colors, fonts, and shadows to everything

**This single step saves you 3+ hours of manual formatting.**

---

## STEP 2 — IMPORT YOUR DATA

1. Click `Home` tab → `Get Data` → `Text/CSV`
2. Select your CSV file → Load
3. Power BI shows the data preview — click `Transform Data`
4. In Power Query Editor, check all columns have correct types:
   - `order_date` → Date
   - `order_id`, `customer_id`, `product_id` → Whole Number
   - `revenue`, `profit`, `product_price`, `shipping_cost`, `discounted_price` → Decimal Number
   - `discount_percent`, `quantity`, `rating` → Whole Number
   - `is_returned` → Whole Number (0 or 1)
   - All text columns → Text
5. Click `Close & Apply`

---

## STEP 3 — CREATE DATE TABLE

1. Click `Modeling` tab → `New Table`
2. Paste this formula:
   ```
   DateTable = CALENDAR( MIN(Sales[order_date]), MAX(Sales[order_date]) )
   ```
3. Then right-click `DateTable` in the Fields pane → `New Column` and add each column from the DAX file (Year, Month Name, etc.)
4. Click `Modeling` → `Mark as Date Table` → select the `Date` column
5. Go to `Model view` (left sidebar, 3rd icon) → drag `DateTable[Date]` to `Sales[order_date]` to create a relationship

---

## STEP 4 — ADD ALL DAX MEASURES

1. Click on your `Sales` table in the Fields pane (right side)
2. Click `Modeling` tab → `New Measure`
3. Open `All_DAX_Measures.dax` in Notepad
4. Copy each measure one by one, paste into the formula bar, press Enter
5. Repeat for all 40+ measures

**Tip:** Create a separate "Measures" table to keep them organized:
- `Modeling` → `New Table` → type `Measures = {0}` → Enter
- Move all your measures into this table by right-clicking → `Move to table`

---

## STEP 5 — DASHBOARD LAYOUT GRID

```
┌─────────────────────────────────────────────────────────────────────┐
│  HEADER BAR (full width, ~60px tall)                                │
│  Logo | Title + Subtitle                     Date Range Slicer      │
├──────────────┬──────────────────────────────────────────────────────┤
│              │  KPI ROW 1: Revenue | Quantity | Return | Lost | Avg │
│  FILTER      │  Rating  (5 cards across, equal width, ~100px tall)  │
│  PANEL       │──────────────────────────────────────────────────────│
│  (190px wide)│  KPI ROW 2: Orders | Customers | Profit | Discount   │
│              │  | Avg Shipping  (5 cards across, ~100px tall)        │
│              │──────────────────────────────────────────────────────│
│  Date        │  Revenue Trend (large) | Revenue by Category |       │
│  Country     │  Return Analysis (donut)                              │
│  Category    │──────────────────────────────────────────────────────│
│  Traffic     │  Revenue by Country (map) | Profit by Traffic |      │
│  Payment     │  Discount vs Profit (scatter) | Rating vs Returns    │
│              │──────────────────────────────────────────────────────│
│  [cart img]  │  Payment Method Table | Shipping vs Profit |         │
│  Data source │  Top Products Table                                   │
├──────────────┴──────────────────────────────────────────────────────┤
│  FOOTER: "All values in USD | PY = Previous Year | Data as of..."  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## STEP 6 — BACKGROUND SHAPES (Glassmorphism Effect)

This is the key to the dark glass card look.

### Full-page background:
Already set via page background color `#0D0F1A`

### Visual card containers (for each section):
1. Click `Insert` tab → `Shapes` → `Rectangle`
2. Draw a rectangle behind each section
3. In `Format Shape` pane (right side):
   - **Fill:** `#161928` | Transparency: `10%`
   - **Border:** Color `#2A2D45` | Width: `1px` | Radius: `12`
   - **Shadow:** ON | Color: `#000000` | Transparency: `65%` | Blur: `10` | Angle: `135°` | Distance: `4`
4. Right-click the rectangle → `Send to Back`

**Do this for:**
- KPI row 1 background (one long rectangle behind all 5 cards)
- KPI row 2 background
- Each chart panel
- The filter panel (left column)

### Individual KPI card containers:
1. Insert Rectangle → draw to ~220px × 100px
2. Fill: `#1A1D2E` | Transparency: `5%`
3. Border: `#2A2D45` | Radius: `12`
4. Shadow: ON | Color `#000000` | Blur: `8` | Transparency: `70%`

---

## STEP 7 — KPI CARDS (Most Important Section)

Each KPI card has 3 elements:
1. Background rectangle (glassmorphism panel)
2. Icon circle (colored circle + icon image)
3. Power BI Card visual (the number + label)

### Step 7A: Add the Card visual
1. Click `Visualizations` pane → Card icon (looks like "123")
2. Drag your measure (e.g., `Total Revenue`) into the `Fields` well
3. Resize to fit inside your KPI rectangle
4. In Format pane:
   - **Callout value:** Font `Segoe UI Black`, Size `28`, Color `#FFFFFF`
   - **Category label:** ON, Size `9`, Color `#9CA3AF`
   - **Background:** OFF (transparent)
   - **Border:** OFF
   - **Padding:** General → 10px all sides

### Step 7B: Add the vs PY subtitle
1. Add another Card visual below the main number
2. Drag the label measure (e.g., `Revenue vs PY Label`) into it
3. Format: Font size `9` | Color: green `#10B981` for positive / red `#EF4444` for negative
4. **Note:** The color will be static unless you use conditional formatting

   **Conditional formatting for the label color:**
   - Click the subtitle Card → Format → Callout value → fx (conditional formatting icon)
   - Rules: If value contains "▲" → Green | If "▼" → Red
   - (Alternatively, accept static color and update manually)

### Step 7C: Add colored icon circles
For each KPI, you need a colored circle with an icon:

1. Insert → Shapes → Oval
2. Hold Shift while drawing to make it a perfect circle (~50×50px)
3. Fill with KPI color (see list below) | No border
4. For the icon inside: go to `flaticon.com` or `icons8.com`
   - Search for the icon (e.g., "revenue", "shopping cart", "star", "return")
   - Download as PNG (white icon, 64×64px)
   - Insert → Image → place on top of the circle

### KPI Icon Colors:
| KPI | Icon Color | HEX |
|---|---|---|
| Total Revenue | Purple | `#A855F7` |
| Total Quantity | Blue | `#3B82F6` |
| Return Rate | Orange | `#F97316` |
| Lost Revenue | Red | `#EF4444` |
| Avg Rating | Gold | `#F59E0B` |
| Total Orders | Green | `#10B981` |
| Total Customers | Blue-purple | `#6366F1` |
| Total Profit | Cyan-blue | `#3B82F6` |
| Total Discount Value | Amber | `#F59E0B` |
| Avg Shipping Cost | Cyan | `#06B6D4` |

### Step 7D: Group KPI elements
1. Hold Ctrl → click the rectangle, circle, icon image, and both card visuals for ONE KPI card
2. Right-click → `Group`
3. Now you can move the whole card as one unit

---

## STEP 8 — LEFT FILTER PANEL

### Panel background:
1. Insert Rectangle → 190px wide, full height minus header
2. Fill: `#1A1D2E` | Transparency: `0%`
3. Border right: `#2A2D45` | Width: `1px`
4. Send to Back

### "FILTERS" header text:
1. Insert → Text Box
2. Type: `FILTERS`
3. Font: Segoe UI Semibold | Size: `12` | Color: `#F59E0B` (yellow/gold)

### For each slicer (Date, Country, Category, Traffic, Payment):
1. Click Visualizations → Slicer (funnel icon)
2. Drag the column into the Field well
3. In Format pane:
   - **Slicer settings → Style:** Dropdown
   - **Values:** Font `Segoe UI`, Size `10`, Color `#D1D5DB`
   - **Background:** `#1A1D2E`
   - **Border:** Color `#2A2D45`, Radius `8`
   - **Shadow:** ON

**Date slicer specifically:**
- Style: `Between` (shows date range picker)
- Header: OFF (slicer header)
- Add a text box above it saying "Date" in grey `#9CA3AF`

**Spacing:** Leave 12px gap between each slicer

---

## STEP 9 — CHARTS

### Chart 1: Revenue Trend Over Time (Line Chart)
- **Visual:** Line Chart
- **Position:** Left side, ~550px wide × 200px tall
- **X-Axis:** DateTable[Month Name]
- **Y-Axis:** Total Revenue, Total Profit
- **Colors:** Revenue = `#A855F7` | Profit = `#3B82F6`
- **Line width:** 2.5px
- **Markers:** OFF
- **Gridlines:** Dashed, color `#1F2235`
- **Legend:** ON, position Top-Left

### Chart 2: Revenue & Profit by Category (Clustered Column + Line)
- **Visual:** Line and Clustered Column Chart
- **Position:** Center, ~380px wide × 200px tall
- **X-Axis:** Sales[product_category]
- **Column Y-Axis:** Total Revenue
- **Line Y-Axis:** Total Profit
- **Column color:** `#A855F7` | Line color: `#3B82F6`
- **Data labels:** ON for bars

### Chart 3: Return Analysis (Donut Chart)
- **Visual:** Donut Chart
- **Position:** Right, ~290px wide × 200px tall
- **Legend:** Sales[is_returned] (1 = Returned, 0 = Not Returned)
- **Values:** Total Orders
- **Colors:** Returned = `#F97316` | Not Returned = `#3B82F6`
- **Inner label:** Add text box in center: "5.01K\nTotal Orders"
- **Detail labels:** Show percentage

### Chart 4: Revenue by Country (Map)
- **Visual:** Map (or ArcGIS Map)
- **Position:** Bottom-left area, ~500px × 200px
- **Location:** Sales[customer_country]
- **Bubble size:** Total Revenue
- **Bubble color:** `#A855F7`
- **Map style:** Dark (in Format → Map styles → select Dark)

### Chart 5: Profit by Traffic Source (Horizontal Bar Chart)
- **Visual:** Clustered Bar Chart (horizontal)
- **Y-Axis:** Sales[traffic_source]
- **X-Axis:** Total Profit
- **Bar color:** `#A855F7`
- **Data labels:** ON, show value (e.g., $112K)

### Chart 6: Discount % vs Profit (Scatter Chart)
- **Visual:** Scatter Chart
- **X-Axis:** Sales[discount_percent]
- **Y-Axis:** Total Profit
- **Legend:** Sales[product_category] (each category = different color)
- **Size:** Leave constant (or use Total Revenue for bubble size)
- **Add trend line:** Analytics pane → Trend Line → ON, dashed, white `#FFFFFF`

### Chart 7: Avg Rating vs Return Rate (Bar Chart)
- **Visual:** Clustered Bar Chart
- **X-Axis:** is_returned (Returned / Not Returned)
- **Y-Axis:** Avg Rating
- **Bar colors:** Returned = `#F97316` | Not Returned = `#3B82F6`
- **Data labels:** ON

### Chart 8: Payment Method Analysis (Table)
- **Visual:** Table
- **Columns:** Payment Method | Total Revenue | Avg Order Value
- Add a **data bar** conditional format on Total Revenue column:
  - Click Revenue column header → Format → Conditional formatting → Data bars → ON
  - Color: `#A855F7`
- Include totals row: Format → Totals → ON

### Chart 9: Shipping Cost vs Profit (Scatter)
- **Visual:** Scatter Chart
- **X-Axis:** Sales[shipping_cost]
- **Y-Axis:** Total Profit
- **Dot color:** `#06B6D4` (cyan)
- **Add trend line**

### Chart 10: Top Products by Revenue (Table)
- **Visual:** Table
- **Columns:** Product ID | Product Category | Revenue | Profit
- **Data bars on Revenue:** Color `#A855F7`
- **Sort:** by Revenue descending
- **Rows to show:** Top 5 (use filter: Top N on product_id by Total Revenue)

---

## STEP 10 — HEADER BAR

1. Insert Rectangle → full width, ~65px tall
2. Fill: `#161928` | Border bottom: `#2A2D45`
3. Insert an image (shopping cart icon, white) on the left ~40×40px
4. Insert Text Box: `E-COMMERCE SALES & PROFITABILITY ANALYSIS`
   - Font: Segoe UI Black | Size: `16` | Color: `#FFFFFF`
5. Insert Text Box: `GLOBAL OVERVIEW DASHBOARD`
   - Font: Segoe UI | Size: `10` | Color: `#9CA3AF`
6. On the right: Add a Date Range slicer
   - Style: Between | Format as a clean rectangle with `#1A1D2E` fill

---

## STEP 11 — FOOTER

1. Insert Rectangle → full width, ~25px tall, at the very bottom
2. Fill: `#161928`
3. Insert Text Box: `ℹ All values are in USD  |  PY = Previous Year  |  Data as of Dec 31, 2024`
   - Font: Segoe UI | Size: `8` | Color: `#9CA3AF`

---

## STEP 12 — ALIGNMENT & SPACING (Professional Rules)

**The golden spacing rules:**
- Gap between visuals: **12–16px**
- Padding inside panels: **16px** from edge to content
- KPI card height: **~100px** uniform across all cards
- All chart heights in a row must be **identical**

**How to align in Power BI:**
1. Hold Ctrl → select multiple visuals
2. Click `Format` tab in ribbon → use Align buttons:
   - Align Left / Align Top / Distribute Horizontally / Distribute Vertically
3. For equal sizing: select all → Format → Width / Height → type same value

**Snap to grid tip:**
- View → Show gridlines → ON
- View → Snap to grid → ON
- This auto-snaps everything while you drag

---

## STEP 13 — PREMIUM FINISHING TOUCHES

### Tooltip pages:
1. Right-click tab at bottom → `Add Page` → name it `Tooltip_Revenue`
2. Set page size to 320×200px (Page Properties)
3. Create a small detailed chart (e.g., monthly trend)
4. Back on main page → click your chart → Format → Tooltip → Type: Report Page → select `Tooltip_Revenue`
5. Now hovering over the chart shows a beautiful rich tooltip

### Conditional formatting for KPI direction:
- Card visuals don't natively change color by value
- Workaround: Use a measure that outputs an HTML color, OR use icons
- Best approach: use **KPI visual** instead of Card for metrics that have direction

### Data labels — always on for bar/column charts

### Legend placement:
- Position legends at Top-Left, never auto
- Turn off legend border

### Final polish checklist:
- [ ] All chart titles are white, consistent size 11pt
- [ ] All axis labels are grey `#9CA3AF`
- [ ] No visual has a white background (should all be dark/transparent)
- [ ] All cards are evenly spaced
- [ ] Shadows on all rectangles
- [ ] Gridlines are dark dashed, not the default grey
- [ ] Theme JSON is applied
- [ ] Date table is marked as date table
- [ ] Relationship created between DateTable and Sales

---

## STEP 14 — ICON RESOURCES

| Site | URL | Notes |
|---|---|---|
| Flaticon | flaticon.com | Download PNG, white, 64px |
| Icons8 | icons8.com | Free with attribution |
| Heroicons | heroicons.com | Clean minimal SVG/PNG |
| Phosphor Icons | phosphoricons.com | Modern outline style |

**Style to download:** Outline or Duotone | White color | 64×64px PNG

**Icons you need:**
- Shopping bag / revenue icon → for Total Revenue
- Box / package → for Total Quantity
- Refresh arrows → for Return Rate
- Downward trend → for Lost Revenue
- Star → for Avg Rating
- Receipt / orders → for Total Orders
- Person / group → for Total Customers
- Coin / profit → for Total Profit
- Tag / discount → for Discount Value
- Truck → for Avg Shipping Cost

---

## TROUBLESHOOTING

| Problem | Fix |
|---|---|
| Date intelligence not working | Mark DateTable as Date Table + create relationship |
| PY measures return blank | Check the relationship between DateTable and Sales |
| Map visual not showing | Enable map visuals: File → Options → Security → Map visuals |
| Theme not applying | Re-apply: View → Themes → Browse for themes |
| Card showing wrong format | Right-click measure → Format → Decimal places + Symbol |
| Visuals look white background | Select visual → Format → Background → OFF or Transparency 100% |

---

*Package created for Hamza's E-Commerce Power BI Dashboard Project*
*Dataset: Shopify Sales Analysis*
