String avatarAssetPath(int index) {
  final safe = index.clamp(1, 12);
  return 'assets/images/avatars/avatar_${safe.toString().padLeft(2, '0')}.png';
}

const Map<int, String> avatarLabels = {
  1: 'Yse the Bookworm',
  2: 'Motter the Otter',
  3: 'Groo the Owl',
  4: 'Fox the Clever',
  5: 'Mouse the Curious',
  6: 'Rabbit the Bookish',
  7: 'Elephant the Wise',
  8: 'Dolphin the Bright',
  9: 'Tarsier the Observant',
  10: 'Carabao the Hardworking',
  11: 'Bear the Patient',
  12: 'Cat the Calm',
};