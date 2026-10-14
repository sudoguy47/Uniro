import type { GoldieConfig } from "C:/Users/sudog/AppData/Roaming/npm/node_modules/goldie/dist/config.js";

const APP_ROOT =
  "C:/Users/sudog/OneDrive/Documents/Android project/StudioProjects/uniro_onboarding/uniro1";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  // No iOS build on this Windows host; the Android block below is what runs.
  // Kept as strings so the config still typechecks.
  appPath:
    "C:/Users/sudog/OneDrive/Documents/Android project/StudioProjects/uniro_onboarding/uniro1/build/app/outputs/flutter-apk/app-x86_64-release.apk",
  bundleId: "com.example.uniro1",

  android: {
    appPath:
      "C:/Users/sudog/OneDrive/Documents/Android project/StudioProjects/uniro_onboarding/uniro1/build/app/outputs/flutter-apk/app-x86_64-release.apk",
    applicationId: "com.example.uniro1",
  },

  devices: ["pixel-10-pro"],
  locales: ["en-US"],
  appearance: "light",

  // Pixel tiles always use the bundled Pixel 10 Pro bezel; no iPhone art needed.
  frame: { variant: "17-pro-blue" },

  theme: {
    background:
      "linear-gradient(165deg, #D97E36 0%, #B45F22 55%, #7A3E14 100%)",
    headlineColor: "#FFFFFF",
    subheadColor: "#FFE8D1",
    fontFamily: "Montserrat",
    copyHeightRatio: 0.24,
    deviceWidthRatio: 0.84,
    template: "editorial",
    layout: "classic",
  },

  store: {
    name: "Uniro — Campus Tasks & Notes",
    subtitle: { "en-US": "Deadlines, notes & reminders" },
    developer: "Uniro",
    category: "Education",
    rating: 4.8,
    ratingCount: "1.2K Ratings",
    ageRating: "Everyone",
    price: "Free",
    description: {
      "en-US":
        "Uniro keeps your whole semester in one place. Capture assignments, exams and class tests in seconds, and let smart reminders make sure nothing slips.\n\nSee every due date on a monthly heatmap, track your weekly load at a glance, and keep study notes with checklists and color tags right next to your tasks.\n\nOffline-first, private by design, and free. Built for students who would rather study than manage apps.",
    },
  },

  scenes: [
    {
      kind: "screenshot",
      id: "onboarding",
      flow: "store-01-onboarding",
      headline: { "en-US": "Your campus, organized" },
      subhead: {
        "en-US": "Deadlines, classes and exams — finally in one place.",
      },
    },
    {
      kind: "screenshot",
      id: "dashboard",
      flow: "store-02-dashboard",
      headline: { "en-US": "Never miss a deadline" },
      subhead: {
        "en-US": "A week view plus auto-reminders keeps you ahead.",
      },
    },
    {
      kind: "screenshot",
      id: "new-task",
      flow: "store-03-new-task",
      headline: { "en-US": "Capture it in seconds" },
      subhead: {
        "en-US": "Title, date and reminders — done before the lecture ends.",
      },
    },
    {
      kind: "screenshot",
      id: "calendar",
      flow: "store-04-calendar",
      headline: { "en-US": "Every due date, one glance" },
      subhead: {
        "en-US": "A monthly heatmap for the whole semester.",
      },
    },
    {
      kind: "screenshot",
      id: "notes",
      flow: "store-05-notes",
      headline: { "en-US": "Notes that keep up" },
      subhead: {
        "en-US": "Checklists, quotes and color tags for every subject.",
      },
    },
    {
      kind: "preview",
      id: "preview",
      segments: [
        { id: "open", flow: "store-preview-01-open" },
        { id: "compose", flow: "store-preview-02-compose" },
        { id: "create", flow: "store-preview-03-create", holdSeconds: 2 },
      ],
    },
  ],
};

export default config;
