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
