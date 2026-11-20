# Generates stim.txt (random windows) and golden.json (expected counters) for tb.cc
import random, json
random.seed(7); N = 32768; rows = []
for i in range(N):
    ab = random.random() < 0.5; bb = random.random() < 0.5
    ai = random.choice([0,1,1,2,2]); bi = random.choice([0,1,1,2,2])
    ap = random.randrange(16); bp = ap if random.random() < 0.4 else random.randrange(16)
    sa = random.random() < 0.29; sb = random.random() < 0.30
    c1 = random.random() < 0.08; c2 = random.random() < 0.08
    rows.append((int(ab),int(bb),ai,bi,ap,bp,int(sa),int(sb),int(c1),int(c2)))
open('stim.txt','w').write("\n".join(" ".join(map(str,r)) for r in rows))
g = dict.fromkeys("n_total n_xm n_zm n_xint n_xacc n_xeff n_xerr n_int0 n_int1 n_int2 c_int0 c_int1 c_int2 n_zcat0 n_zcat1 n_zcat2 n_zcat3 n_zeff n_zerr".split(), 0)
for ab,bb,ai,bi,ap,bp,sa,sb,c1,c2 in rows:
    g['n_total'] += 1; bm = ab == bb; xm = bm and not ab; zm = bm and ab
    eff = c1 ^ c2; d = (bp-ap) % 16; cosneg = 5 <= d <= 11
    wrong = (c1 and cosneg) or (c2 and not cosneg)
    xint = xm and ai == bi; acc = xint and ai != 0 and ap == bp
    g['n_xm'] += xm; g['n_zm'] += zm; g['n_xint'] += xint; g['n_xacc'] += acc
    if acc and eff: g['n_xeff'] += 1
    if acc and eff and wrong: g['n_xerr'] += 1
    if xint:
        g['n_int%d' % ai] += 1
        if eff: g['c_int%d' % ai] += 1
    zc = (sa << 1) | sb
    if zm:
        g['n_zcat%d' % {2:0,1:1,3:2,0:3}[zc]] += 1
        if eff: g['n_zeff'] += 1
        if eff and zc in (3,0): g['n_zerr'] += 1
json.dump(g, open('golden.json','w'))
