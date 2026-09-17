/// 语义化版本比对（CI Tag / 公告 JSON / 应用内三处版本一致性用）。
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.pre]);

  factory SemVer.parse(String input) {
    var s = input.trim();
    if (s.startsWith('v')) s = s.substring(1);
    String? pre;
    if (s.contains('-')) {
      final int index = s.indexOf('-');
      pre = s.substring(index + 1);
      s = s.substring(0, index);
    }
    if (s.contains('+')) s = s.substring(0, s.indexOf('+'));
    final parts = s.split('.');
    int num(int i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    return SemVer(num(0), num(1), num(2), pre);
  }

  final int major;
  final int minor;
  final int patch;
  final String? pre;

  bool get isPre => pre != null && pre!.isNotEmpty;

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (!isPre && other.isPre) return 1;
    if (isPre && !other.isPre) return -1;
    if (!isPre && !other.isPre) return 0;
    final a = pre!.split('.');
    final b = other.pre!.split('.');
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final an = i < a.length ? int.tryParse(a[i]) : null;
      final bn = i < b.length ? int.tryParse(b[i]) : null;
      if (an != null && bn != null) {
        if (an != bn) return an.compareTo(bn);
      } else if (an != null) {
        return -1;
      } else if (bn != null) {
        return 1;
      } else {
        final as = i < a.length ? a[i] : '';
        final bs = i < b.length ? b[i] : '';
        if (as != bs) return as.compareTo(bs);
      }
    }
    return 0;
  }

  bool isNewerThan(SemVer other) => compareTo(other) > 0;

  @override
  String toString() =>
      isPre ? '$major.$minor.$patch-$pre' : '$major.$minor.$patch';
}
