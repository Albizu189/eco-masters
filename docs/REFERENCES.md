# Rules and component references

These external references were used to verify mechanics and component counts. They remain the property of their respective owners and are linked rather than copied into the project.

- Libellud — Harmonies game page: https://www.libellud.com/game/harmonies/
- Libellud — Harmonies resources: https://www.libellud.com/en/resources/harmonies/
- English rulebook mirror used for reading: https://officialgamerules.org/wp-content/uploads/2025/04/HARMONIES_RULES_EN-1-1.pdf
- Board Game Arena — Harmonies rules help: https://en.boardgamearena.com/doc/Gamehelpharmonies
- Godot 4.4 Android library documentation: https://docs.godotengine.org/en/4.4/tutorials/platform/android/android_library.html

## Verified physical component counts

- 120 landscape tokens: 23 water, 23 mountain, 21 trunk, 19 foliage, 19 field, and 15 building.
- 32 Animal cards and 10 Nature’s Spirit cards.
- Double-sided personal boards and a three-group solo token market.

The digital card data in `scripts/rules.gd` records each habitat’s ordered shape, exact stack requirements, cube target, score ladder, and Nature’s Spirit scoring rule. The tests instantiate every pattern in all six rotations.
