import fs from 'node:fs';
import { execSync } from 'node:child_process';

const courses = [
  { id: "c1", name: "Operating Systems", code: "CSE 321", colorTag: 4293424700, teacher: "Dr. Sarah Jenkins", room: "Room 402", credits: 3.0 },
  { id: "c2", name: "Database Management", code: "CSE 311", colorTag: 4281729625, teacher: "Prof. David Clark", room: "Lab 3", credits: 3.0 },
  { id: "c3", name: "Computer Networks", code: "CSE 325", colorTag: 4277708575, teacher: "Dr. Alan Miller", room: "Auditorium B", credits: 4.0 },
  { id: "c4", name: "Software Engineering", code: "CSE 331", colorTag: 4292415293, teacher: "Engr. Sophia Lee", room: "Hall 101", credits: 3.0 }
];

const slots = [
  { id: "s1", courseId: "c1", weekday: 3, startMinutes: 540, endMinutes: 620, room: "Room 402", reminderMinutesBefore: 15 },
  { id: "s2", courseId: "c2", weekday: 3, startMinutes: 640, endMinutes: 730, room: "Lab 3", reminderMinutesBefore: 15 },
  { id: "s3", courseId: "c3", weekday: 3, startMinutes: 780, endMinutes: 870, room: "Auditorium B", reminderMinutesBefore: 15 },
  { id: "s4", courseId: "c4", weekday: 3, startMinutes: 900, endMinutes: 990, room: "Hall 101", reminderMinutesBefore: 15 }
];

const notes = [
  {
    id: "n1",
    title: "Operating Systems - Final Exam Prep",
    blocks: [
      { id: "b1", type: "paragraph", text: "Key Exam Topics:\n1. Virtual memory & paging replacement (LRU, Optimal)\n2. Deadlock conditions & Banker's Algorithm\n3. Mutex locks and semaphores implementation" }
    ],
    folder: "Study",
    isPinned: true,
    isLocked: false,
    createdAt: "2026-10-14T10:00:00.000000",
    updatedAt: "2026-10-14T14:30:00.000000",
    courseId: "c1"
  },
  {
    id: "n2",
    title: "Networks Lab 5 - Wireshark Checklist",
    blocks: [
      { id: "b2", type: "checklist", text: "Capture TCP three-way handshake trace" },
      { id: "b3", type: "checklist", text: "Calculate round-trip time (RTT)" },
      { id: "b4", type: "checklist", text: "Export packet graph and submit report" }
    ],
    folder: "Study",
    isPinned: false,
    isLocked: false,
    createdAt: "2026-10-13T16:00:00.000000",
    updatedAt: "2026-10-14T09:15:00.000000",
    courseId: "c3"
  },
  {
    id: "n3",
    title: "Database Indexing and Normalization",
    blocks: [
      { id: "b5", type: "paragraph", text: "BCNF decomposition vs 3NF. B+ Tree indexing for fast range scans and primary keys." }
    ],
    folder: "Personal",
    isPinned: false,
    isLocked: false,
    createdAt: "2026-10-12T11:20:00.000000",
    updatedAt: "2026-10-14T08:00:00.000000",
    courseId: "c2"
  }
];

execSync("adb -s emulator-5554 pull /data/data/com.example.uniro1/shared_prefs/FlutterSharedPreferences.xml prefs.xml");
let xml = fs.readFileSync("prefs.xml", "utf8");

function setString(xml, key, jsonVal) {
  const enc = JSON.stringify(jsonVal).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const regex = new RegExp("<string name=\"" + key + "\">.*?</string>", "s");
  const tag = "<string name=\"" + key + "\">" + enc + "</string>";
  if (regex.test(xml)) {
    return xml.replace(regex, tag);
  } else {
    return xml.replace("</map>", "    " + tag + "\n</map>");
  }
}

xml = setString(xml, "flutter.ct_courses", courses);
xml = setString(xml, "flutter.ct_slots", slots);
xml = setString(xml, "flutter.uniro_notes_v1", notes);

fs.writeFileSync("prefs.xml", xml);
execSync("adb -s emulator-5554 push prefs.xml /data/data/com.example.uniro1/shared_prefs/FlutterSharedPreferences.xml");
execSync("adb -s emulator-5554 shell am force-stop com.example.uniro1");
execSync("adb -s emulator-5554 shell monkey -p com.example.uniro1 -c android.intent.category.LAUNCHER 1");
console.log("Seeded successfully!");
