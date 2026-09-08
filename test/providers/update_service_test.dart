import 'package:flauncher/providers/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("preferredAbi", () {
    test("returns the first published ABI in device order", () {
      expect(preferredAbi(["arm64-v8a", "armeabi-v7a", "x86_64"]), "arm64-v8a");
    });

    test("32-bit device selects armeabi-v7a, ignoring unpublished ABIs", () {
      expect(preferredAbi(["armeabi-v7a", "armeabi"]), "armeabi-v7a");
    });

    test("x86_64-only device selects x86_64", () {
      expect(preferredAbi(["x86_64", "x86"]), "x86_64");
    });

    test("returns null when none of the published ABIs is supported", () {
      expect(preferredAbi(["mips64", "riscv64"]), isNull);
      expect(preferredAbi(["armeabi"]), isNull);
      expect(preferredAbi([]), isNull);
    });
  });

  group("versionCodeFromVersionName", () {
    test("weights semantic versions like the CI algorithm", () {
      expect(versionCodeFromVersionName("1.0.1"), 1001000);
      expect(versionCodeFromVersionName("1.2.3"), 1203000);
      expect(versionCodeFromVersionName("1.0.1-alpha.4"), 1001104);
      expect(versionCodeFromVersionName("1.0.1-beta.1"), 1001201);
      expect(versionCodeFromVersionName("1.0.1-rc.2"), 1001302);
    });

    test("returns null for non-semantic versions", () {
      expect(versionCodeFromVersionName("2024.11.001"), isNull);
      expect(versionCodeFromVersionName("dev"), isNull);
      expect(versionCodeFromVersionName(""), isNull);
    });
  });
}