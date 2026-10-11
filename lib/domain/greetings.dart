/// Time-aware greeting + subtitle for the dashboard header,
/// plus a daily motivational line revealed by swiping up on the header.
class Greeting {
  const Greeting({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

Greeting greetingFor(DateTime now, String name) {
  final h = now.hour;
  if (h >= 5 && h < 8) {
    return Greeting(
      title: 'Rise and shine, $name! \u2600\uFE0F',
      subtitle: 'A fresh day, a fresh start.',
    );
  }
  if (h >= 8 && h < 12) {
    return Greeting(
      title: 'Good morning, $name!',
      subtitle: 'Ready to learn something new?',
    );
  }
  if (h >= 12 && h < 15) {
    return Greeting(
      title: 'Hey, $name! \uD83C\uDF24\uFE0F',
      subtitle: 'One step closer to your goals.',
    );
  }
  if (h >= 15 && h < 18) {
    return Greeting(
      title: 'Keep it up, $name!',
      subtitle: "You're making progress, one task at a time.",
    );
  }
  if (h >= 18 && h < 21) {
    return Greeting(
      title: 'Good evening, $name! \uD83C\uDF06',
      subtitle: "Let's make the rest of today count.",
    );
  }
  if (h >= 21) {
    return Greeting(
      title: 'Still studying, $name? \uD83C\uDF19',
      subtitle: 'Small efforts today, big results tomorrow.',
    );
  }
  return Greeting(
    title: 'Burning the midnight oil, $name?',
    subtitle: "Don't forget to give yourself some rest.",
  );
}

/// Split greeting for the two-line dashboard header.
/// Line 1 = time-based greeting ("Good morning,"), line 2 = student name.
String greetingHeadline(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 8) return 'Rise and shine,';
  if (h >= 8 && h < 12) return 'Good morning,';
  if (h >= 12 && h < 15) return 'Hey,';
  if (h >= 15 && h < 18) return 'Keep it up,';
  if (h >= 18 && h < 21) return 'Good evening,';
  if (h >= 21) return 'Still studying,';
  return 'Midnight grind,';
}

/// Emoji paired with the split greeting ('' when the slot has none).
String greetingEmojiFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 8) return ' \u2600\uFE0F';
  if (h >= 12 && h < 15) return ' \uD83C\uDF24\uFE0F';
  if (h >= 18 && h < 21) return ' \uD83C\uDF06';
  if (h >= 21 || h < 5) return ' \uD83C\uDF19';
  return '';
}
String shortGreetingFor(DateTime now, String name) {
  final h = now.hour;
  if (h >= 5 && h < 8) return 'Rise and shine, $name! \u2600\uFE0F';
  if (h >= 8 && h < 12) return 'Good morning, $name!';
  if (h >= 12 && h < 15) return 'Hey, $name! \uD83C\uDF24\uFE0F';
  if (h >= 15 && h < 18) return 'Keep it up, $name!';
  if (h >= 18 && h < 21) return 'Good evening, $name! \uD83C\uDF06';
  if (h >= 21) return 'Still studying, $name? \uD83C\uDF19';
  return 'Midnight grind, $name? \uD83C\uDF19';
}

/// The user's 20 daily quotes — cycled strictly one per day, in order.
/// Both the dashboard header ("Daily Fuel") and the 6 AM notification use
/// the SAME entry, so the quote you wake up to is the quote on your
/// dashboard all day. No repeats within a 20-day cycle, no randomness.
String _quoteForDay(DateTime now) {
  final startOfYear = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(startOfYear).inDays;
  return _dailyQuotes[dayOfYear % _dailyQuotes.length];
}

/// Dashboard header quote of the day.
String quoteOfTheDay(DateTime now) => _quoteForDay(now);

/// Morning-notification quote of the day (same rotation as the header).
String lifeQuoteOfTheDay(DateTime now) => _quoteForDay(now);

const _dailyQuotes = [
  "Good morning! Today is another chance to become who you want to be.",
  "Wake up with gratitude, move forward with purpose.",
  "A new day, a fresh start, endless possibilities.",
  "Start small, stay consistent, and trust your growth.",
  "Let today be guided by kindness and curiosity.",
  "You don't need to have it all figured out. Just take the first step.",
  "Every sunrise is a gentle reminder that you can begin again.",
  "Make today count, not by doing everything, but by doing what matters.",
  "Fill your mind with knowledge and your heart with kindness.",
  "Good things take time. Be patient with yourself today.",
  "Before chasing your dreams, take a moment to be grateful for this day.",
  "Let your actions reflect your dreams, and your kindness reflect your character.",
  "A peaceful mind and a willing heart are a beautiful way to begin the day.",
  "Learn something new, help someone out, and grow a little today.",
  "Don't let yesterday's mistakes steal today's opportunities.",
  "May your day be productive, your heart be light, and your intentions be good.",
  "Do your best today, and leave the rest to God.",
  "You are here to learn, to grow, and to make a difference.",
  "Take a deep breath. You're allowed to grow at your own pace.",
  "Good morning! Become a little wiser, kinder, and stronger today.",
];
