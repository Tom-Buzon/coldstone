# Asset sources

- Quaternius — Universal Animation Library (CC0)
  https://quaternius.itch.io/universal-animation-library
- Quaternius — Universal Animation Library 2 (CC0)
  https://quaternius.itch.io/universal-animation-library-2
- Quaternius — Ultimate Animated Animal Pack, 12 modèles animés (CC0)
  https://quaternius.com/packs/ultimateanimatedanimals.html
- Quaternius — Animal Pack Vol.2, aigle uniquement (CC0)
  https://opengameart.org/node/78596
- tewrwfwff — Velociraptor-with-fixed-colour (1) (CC BY 4.0)
  https://skfb.ly/oyL79
- dead tubby's — Tiranosaurus from unity (CC BY 4.0)
  https://skfb.ly/oKTAG
- LasquetiSpice — Animated Flying Pteradactal Dinosaur Loop (CC BY 4.0)
  https://skfb.ly/o9nTY

The setup script downloads the Standard archives from their OpenGameArt mirrors and copies only the Godot-compatible Standard GLBs into `assets/runtime/`.

Fauna assets are stored under `assets/fauna/`; the original Eagle Blender source is kept under `_source/fauna/` and converted reproducibly with `tools/import_quaternius_eagle.py`.

The Sketchfab GLBs keep their embedded rigs and animation clips. Per-asset attribution and license details are stored beside each model in `LICENSE.txt`.
