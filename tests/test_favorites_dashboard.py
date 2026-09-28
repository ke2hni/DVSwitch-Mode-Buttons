"""Check the mode-scoped Favorites path is wired into the dashboard installer."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / 'dvswitch-mode-buttons.sh').read_text()
SCRIPT = (ROOT / 'dvswitch-mode-favorites.js').read_text()
HELPER = (ROOT / 'dvswitch-mode-favorites').read_text()


class FavoritesDashboardTests(unittest.TestCase):
    def test_dashboard_loads_favorites_for_active_mode_and_provides_mode_editor(self):
        self.assertIn("load(activeMode)", SCRIPT)
        self.assertIn("selector.addEventListener('change', loadEditorMode)", SCRIPT)
        self.assertIn("selector.innerHTML", SCRIPT)
        for mode in ('BM', 'TGIF', 'STFU', 'YSF', 'P25', 'NXDN', 'DSTAR'):
            self.assertIn("value=\"%s\"" % mode, SCRIPT)
        self.assertIn("input.value = favorite.target", SCRIPT)
        self.assertIn("tuner.requestSubmit()", SCRIPT)

    def test_editor_save_is_server_validated_and_uses_root_helper(self):
        self.assertIn("'application/json') === 0", INSTALLER)
        self.assertIn("/usr/local/sbin/dvswitch-mode-favorites", INSTALLER)
        self.assertIn("www-data ALL=(root) NOPASSWD: /usr/local/sbin/dvswitch-mode-favorites", INSTALLER)
        self.assertIn("re.fullmatch(r'[A-Za-z0-9_-]{1,32}', target)", HELPER)
        self.assertIn('os.replace(temporary, PATH)', HELPER)
        self.assertIn('len(items) > 30', HELPER)

    def test_test18_upgrade_and_uninstall_cover_the_favorites_script(self):
        self.assertIn('VERSION="1.0.0-test18"', INSTALLER)
        self.assertIn('|17|18', INSTALLER)
        self.assertIn('dvswitch-mode-favorites.js', INSTALLER)
        self.assertIn('./dvswitch-mode-favorites "$FAVORITES_HELPER"', INSTALLER)


if __name__ == '__main__':
    unittest.main()
