import json, os, subprocess, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__)); PY = os.path.join(HERE, "..", "python")
sys.path.insert(0, PY)
import sifter_model as m


class ModelTests(unittest.TestCase):
    def test_ten_window_table_4_3(self):
        rows = [(0,0,1,1,3,3,0,0,1,0), (0,0,2,2,5,5,0,0,0,1), (1,1,0,0,0,0,1,0,1,0), (1,0,0,0,0,0,0,0,0,0),
                (0,0,1,2,2,6,0,0,0,1), (1,1,0,0,0,0,1,1,1,1), (0,0,0,0,0,0,0,0,0,0), (0,0,1,1,4,9,0,0,1,0),
                (1,1,0,0,0,0,0,0,1,0), (0,0,2,2,7,7,0,0,1,1)]
        c = m.count(rows)
        for k, v in dict(n_total=10, n_xm=6, n_zm=3, n_xint=5, n_xacc=3, n_xeff=2, n_xerr=1, n_zeff=2, n_zerr=1).items():
            self.assertEqual(c[k], v, k)

    def test_independent_models_agree_with_report_table_4_2(self):
        with tempfile.TemporaryDirectory() as d:
            subprocess.check_call([sys.executable, os.path.join(PY, "golden_model.py")], cwd=d)
            with open(os.path.join(d, "golden.json")) as f:
                gold = json.load(f)
            with open(os.path.join(d, "stim.txt")) as f:
                rows = [tuple(map(int, l.split())) for l in f if l.strip()]
        self.assertEqual(gold, m.count(rows))
        self.assertEqual((gold["n_xm"], gold["c_int1"], gold["n_zerr"]), (8164, 203, 755))

    def test_counters_are_consistent(self):
        for seed in range(5):
            c = m.count(m.gen_random(seed, 5000, pclick=0.3))
            self.assertLessEqual(c["n_xm"] + c["n_zm"], c["n_total"])
            self.assertEqual(c["n_zcat0"] + c["n_zcat1"] + c["n_zcat2"] + c["n_zcat3"], c["n_zm"])
            self.assertEqual(c["n_int0"] + c["n_int1"] + c["n_int2"], c["n_xint"])
            self.assertTrue(c["n_xerr"] <= c["n_xeff"] <= c["n_xacc"] <= c["n_xint"] <= c["n_xm"])
            self.assertTrue(c["n_zerr"] <= c["n_zeff"] <= c["n_zm"])

    def test_wrap(self):
        self.assertEqual(m.count([(0,0,1,1,3,3,0,0,1,0)] * 40, cw=4)["n_total"], 8)


class CompareScriptTests(unittest.TestCase):
    def run_cmp(self, a, b):
        with tempfile.TemporaryDirectory() as d:
            pa, pb = os.path.join(d, "a.json"), os.path.join(d, "b.json")
            for path, obj in ((pa, a), (pb, b)):
                with open(path, "w") as f:
                    json.dump(obj, f)
            return subprocess.run([sys.executable, os.path.join(PY, "compare_counters.py"), pa, pb],
                                  capture_output=True, text=True)

    def test_match_and_mismatch_and_missing_key(self):
        g = dict.fromkeys(m.KEYS, 3)
        self.assertEqual(self.run_cmp(g, g).returncode, 0)
        b = dict(g); b["n_zerr"] = 4
        r = self.run_cmp(g, b); self.assertEqual(r.returncode, 1); self.assertIn("MISMATCH", r.stdout)
        b = dict(g); del b["n_xm"]
        self.assertEqual(self.run_cmp(g, b).returncode, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
