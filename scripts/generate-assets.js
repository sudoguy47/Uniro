const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

async function main() {
  const publicDir = path.join(__dirname, '..', 'public');
  const capturedDir = path.join(publicDir, 'screenshots', 'captured');
  if (!fs.existsSync(capturedDir)) {
    fs.mkdirSync(capturedDir, { recursive: true });
  }

  // 1. Generate mascot SVG & PNG
  const mascotSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 250" width="960" height="1000" fill="none">
  <defs>
    <radialGradient id="gradGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#D5803B" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#D5803B" stop-opacity="0"/>
    </radialGradient>
    <filter id="softShadow" x="-10%" y="-10%" width="120%" height="130%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#D5803B" flood-opacity="0.18"/>
    </filter>
  </defs>

  <!-- Warm background glow circle -->
  <ellipse cx="120" cy="155" rx="100" ry="85" fill="url(#gradGlow)"/>

  <!-- Mascot body with soft drop shadow -->
  <g filter="url(#softShadow)">
    <path d="M40 140 Q30 90 60 65 Q90 35 120 32 Q150 35 180 65 Q210 90 200 140 Q195 185 120 195 Q45 185 40 140Z" fill="#FFFDF9" stroke="#EAE2D5" stroke-width="3"/>
  </g>

  <!-- Mortarboard cap board & base -->
  <ellipse cx="120" cy="46" rx="74" ry="20" fill="#1C1917"/>
  <rect x="86" y="28" width="68" height="22" rx="7" fill="#1C1917"/>

  <!-- Golden/Burnt-orange graduation tassel -->
  <line x1="192" y1="46" x2="192" y2="84" stroke="#D56E28" stroke-width="5" stroke-linecap="round"/>
  <circle cx="192" cy="88" r="7" fill="#D56E28"/>

  <!-- Big friendly eyes -->
  <ellipse cx="90" cy="118" rx="19" ry="21" fill="#1C1917"/>
  <ellipse cx="150" cy="118" rx="19" ry="21" fill="#1C1917"/>

  <!-- Eye reflections / highlights -->
  <ellipse cx="96" cy="113" rx="7.5" ry="8.5" fill="#FFFFFF"/>
  <ellipse cx="156" cy="113" rx="7.5" ry="8.5" fill="#FFFFFF"/>
  <ellipse cx="99" cy="111" rx="3.5" ry="4" fill="#1C1917"/>
  <ellipse cx="159" cy="111" rx="3.5" ry="4" fill="#1C1917"/>

  <!-- Eyebrows / lashes -->
  <line x1="77" y1="99" x2="73" y2="90" stroke="#1C1917" stroke-width="3" stroke-linecap="round"/>
  <line x1="88" y1="96" x2="86" y2="86" stroke="#1C1917" stroke-width="3" stroke-linecap="round"/>
  <line x1="137" y1="96" x2="135" y2="86" stroke="#1C1917" stroke-width="3" stroke-linecap="round"/>
  <line x1="148" y1="99" x2="152" y2="90" stroke="#1C1917" stroke-width="3" stroke-linecap="round"/>

  <!-- Cheerful warm smile -->
  <path d="M96 153 Q120 172 144 153" stroke="#1C1917" stroke-width="4.5" stroke-linecap="round" fill="none"/>

  <!-- Warm burnt-orange blush cheeks -->
  <ellipse cx="74" cy="146" rx="14" ry="10" fill="#E8823B" opacity="0.45"/>
  <ellipse cx="166" cy="146" rx="14" ry="10" fill="#E8823B" opacity="0.45"/>
</svg>
  `.trim();

  const mascotPngPath = path.join(publicDir, 'screenshots', 'mascot-grad.png');
  await sharp(Buffer.from(mascotSvg)).png().toFile(mascotPngPath);
  console.log('Saved mascot PNG to:', mascotPngPath);

  // 2. Generate Slide 1 Hero Card (Full phone mock / card for hero)
  const heroCardSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 2400" width="1080" height="2400" fill="none">
  <!-- Warm cream paper background -->
  <rect width="1080" height="2400" fill="#FAF6F0"/>

  <defs>
    <radialGradient id="heroBgGlow" cx="50%" cy="35%" r="45%">
      <stop offset="0%" stop-color="#D56E28" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#FAF6F0" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1080" height="2400" fill="url(#heroBgGlow)"/>

  <!-- Mascot Center Stage -->
  <g transform="translate(180, 480) scale(2.8)">
    ${mascotSvg}
  </g>

  <!-- Floating Feature Cards on Hero -->
  <!-- Card 1: Offline First Badge -->
  <g transform="translate(120, 1380)">
    <rect width="400" height="110" rx="28" fill="#FFFFFF" stroke="#EAE2D5" stroke-width="2"/>
    <circle cx="56" cy="55" r="24" fill="#FEF3C7"/>
    <text x="56" y="62" font-family="-apple-system, system-ui, sans-serif" font-size="24" font-weight="900" fill="#D97706" text-anchor="middle">⚡</text>
    <text x="100" y="50" font-family="-apple-system, system-ui, sans-serif" font-size="28" font-weight="800" fill="#1C1917">100% Offline</text>
    <text x="100" y="80" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C">No login needed</text>
  </g>

  <!-- Card 2: Smart reminders -->
  <g transform="translate(560, 1380)">
    <rect width="400" height="110" rx="28" fill="#FFFFFF" stroke="#EAE2D5" stroke-width="2"/>
    <circle cx="56" cy="55" r="24" fill="#FFEDD5"/>
    <text x="56" y="62" font-family="-apple-system, system-ui, sans-serif" font-size="24" font-weight="900" fill="#D56E28" text-anchor="middle">🔔</text>
    <text x="100" y="50" font-family="-apple-system, system-ui, sans-serif" font-size="28" font-weight="800" fill="#1C1917">Smart Alerts</text>
    <text x="100" y="80" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C">Never miss deadlines</text>
  </g>

  <!-- Card 3: Semester load bar preview -->
  <g transform="translate(120, 1530)">
    <rect width="840" height="180" rx="32" fill="#FFFFFF" stroke="#EAE2D5" stroke-width="2"/>
    <text x="48" y="65" font-family="-apple-system, system-ui, sans-serif" font-size="30" font-weight="800" fill="#1C1917">Semester at a glance</text>
    <text x="48" y="105" font-family="-apple-system, system-ui, sans-serif" font-size="22" font-weight="600" fill="#78716C">Assignments · Exams · Labs · Notes</text>
    <rect x="48" y="132" width="744" height="14" rx="7" fill="#F5EFE6"/>
    <rect x="48" y="132" width="480" height="14" rx="7" fill="#D56E28"/>
  </g>
</svg>
  `.trim();

  const heroCardPath = path.join(publicDir, 'screenshots', 'captured', '01-hero-brand.png');
  await sharp(Buffer.from(heroCardSvg)).png().toFile(heroCardPath);
  console.log('Saved 01-hero-brand.png');

  // 3. Generate Slide 6: Home-Screen Widgets + 6 AM Daily Greeting Notification
  const widgetScreenSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 2400" width="1080" height="2400" fill="none">
  <!-- Subtle warm wallpaper -->
  <rect width="1080" height="2400" fill="#F4EEE5"/>

  <!-- Wallpaper accent orbs -->
  <circle cx="200" cy="500" r="350" fill="#EADCC9" opacity="0.6"/>
  <circle cx="850" cy="1100" r="420" fill="#E6D3BE" opacity="0.5"/>

  <!-- Status Bar Time -->
  <text x="120" y="110" font-family="-apple-system, system-ui, sans-serif" font-size="40" font-weight="700" fill="#1C1917">6:00</text>

  <!-- 6 AM Morning Notification Banner -->
  <g transform="translate(70, 240)">
    <rect width="940" height="210" rx="38" fill="rgba(255, 255, 255, 0.92)" stroke="rgba(255, 255, 255, 0.8)" stroke-width="2"/>
    <!-- App Icon in notification -->
    <rect x="36" y="36" width="64" height="64" rx="18" fill="#D56E28"/>
    <text x="68" y="78" font-family="-apple-system, system-ui, sans-serif" font-size="34" font-weight="900" fill="#FFFFFF" text-anchor="middle">U</text>
    <text x="120" y="62" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="800" fill="#78716C">UNIRO · 6:00 AM</text>
    <text x="120" y="102" font-family="-apple-system, system-ui, sans-serif" font-size="30" font-weight="800" fill="#1C1917">Good morning, Alex! ☀️</text>
    <text x="120" y="146" font-family="-apple-system, system-ui, sans-serif" font-size="24" font-weight="500" fill="#57534E">You have 2 assignments due this week. You’ve got this!</text>
  </g>

  <!-- Home Screen Widget: Medium Task Tracker Widget -->
  <g transform="translate(70, 530)">
    <rect width="940" height="480" rx="46" fill="#FFFDF9" stroke="#EAE2D5" stroke-width="2"/>
    <text x="56" y="76" font-family="-apple-system, system-ui, sans-serif" font-size="32" font-weight="900" fill="#1C1917">Today's Focus</text>
    <rect x="740" y="44" width="144" height="42" rx="21" fill="#FEF3C7"/>
    <text x="812" y="72" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="800" fill="#D97706" text-anchor="middle">3 DUE SOON</text>

    <!-- Task item 1 in widget -->
    <g transform="translate(56, 120)">
      <rect width="828" height="96" rx="22" fill="#FAF6F0"/>
      <circle cx="48" cy="48" r="16" fill="none" stroke="#D56E28" stroke-width="3"/>
      <text x="88" y="46" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="700" fill="#1C1917">Operating Systems - Assignment 2</text>
      <text x="88" y="76" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#D56E28">Assignment · Today at 5:00 PM</text>
    </g>

    <!-- Task item 2 in widget -->
    <g transform="translate(56, 236)">
      <rect width="828" height="96" rx="22" fill="#FAF6F0"/>
      <circle cx="48" cy="48" r="16" fill="none" stroke="#EAB308" stroke-width="3"/>
      <text x="88" y="46" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="700" fill="#1C1917">DBMS Quiz 3 Preparation</text>
      <text x="88" y="76" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C">Class Test · Tomorrow 10:00 AM</text>
    </g>

    <!-- Task item 3 in widget -->
    <g transform="translate(56, 352)">
      <rect width="828" height="96" rx="22" fill="#FAF6F0"/>
      <circle cx="48" cy="48" r="16" fill="none" stroke="#10B981" stroke-width="3"/>
      <text x="88" y="46" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="700" fill="#1C1917">Computer Networks Lab Report</text>
      <text x="88" y="76" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C">Lab · Thursday 2:00 PM</text>
    </g>
  </g>

  <!-- Small Widget: Weekly Load Heatmap -->
  <g transform="translate(70, 1070)">
    <rect width="450" height="420" rx="46" fill="#FFFDF9" stroke="#EAE2D5" stroke-width="2"/>
    <text x="44" y="68" font-family="-apple-system, system-ui, sans-serif" font-size="28" font-weight="900" fill="#1C1917">Weekly Load</text>
    <text x="44" y="104" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C">7 tasks pending</text>
    <!-- mini load bars -->
    <g transform="translate(44, 150)">
      <rect x="0" y="160" width="36" height="40" rx="8" fill="#EAE2D5"/>
      <rect x="52" y="80" width="36" height="120" rx="8" fill="#D56E28"/>
      <rect x="104" y="110" width="36" height="90" rx="8" fill="#D56E28"/>
      <rect x="156" y="50" width="36" height="150" rx="8" fill="#D56E28"/>
      <rect x="208" y="130" width="36" height="70" rx="8" fill="#EAE2D5"/>
      <rect x="260" y="170" width="36" height="30" rx="8" fill="#EAE2D5"/>
      <rect x="312" y="180" width="36" height="20" rx="8" fill="#EAE2D5"/>
      <text x="18" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#78716C" text-anchor="middle">M</text>
      <text x="70" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#1C1917" text-anchor="middle">T</text>
      <text x="122" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#1C1917" text-anchor="middle">W</text>
      <text x="174" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#D56E28" text-anchor="middle">T</text>
      <text x="226" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#1C1917" text-anchor="middle">F</text>
      <text x="278" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#78716C" text-anchor="middle">S</text>
      <text x="330" y="226" font-size="16" font-family="sans-serif" font-weight="700" fill="#78716C" text-anchor="middle">S</text>
    </g>
  </g>

  <!-- Small Widget: Quick Quick Capture -->
  <g transform="translate(560, 1070)">
    <rect width="450" height="420" rx="46" fill="#FFFDF9" stroke="#EAE2D5" stroke-width="2"/>
    <circle cx="225" cy="180" r="64" fill="#D56E28"/>
    <text x="225" y="196" font-family="-apple-system, system-ui, sans-serif" font-size="64" font-weight="300" fill="#FFFFFF" text-anchor="middle">+</text>
    <text x="225" y="296" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="800" fill="#1C1917" text-anchor="middle">Quick Add</text>
    <text x="225" y="332" font-family="-apple-system, system-ui, sans-serif" font-size="20" font-weight="600" fill="#78716C" text-anchor="middle">New task or note</text>
  </g>
</svg>
  `.trim();

  const widgetPath = path.join(publicDir, 'screenshots', 'captured', '06-widgets-notifications.png');
  await sharp(Buffer.from(widgetScreenSvg)).png().toFile(widgetPath);
  console.log('Saved 06-widgets-notifications.png');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
