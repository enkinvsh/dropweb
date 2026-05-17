# Source availability for direct APK releases

Every direct APK release must publish complete corresponding source for the exact binary before any public download link goes live.

Required per release:

- Exact Dropweb app commit hash used to build the APK.
- Public repository URL for that commit or a source archive URL for the same source tree.
- GPL-3.0 license text and a source link that makes the GPL-covered code available with the binary.
- Upstream FlClashX attribution, including a link to the upstream project.
- Build instructions that match the published APK version, channel, ABI set, and release configuration.
- List of included prebuilt binaries, with source or upstream references where applicable.
- APK SHA-256 and Android signing certificate SHA-256 published alongside release metadata.
- zencab cabinet source URL and commit when the APK depends on the served cabinet login, payment, support, or bridge flow.

Future release manifest fields must include:

```json
{
  "sourceUrl": "https://github.com/enkinvsh/dropweb/tree/<commit>",
  "sourceArchiveUrl": "https://dropweb.org/releases/dropweb-<version>-source.tar.gz",
  "license": "GPL-3.0",
  "cabinetSourceUrl": "https://github.com/enkinvsh/zencab/tree/<commit>"
}
```

Gate: do not publish direct APK download links on `dropweb.org` until the exact-version source links, license notice, APK checksum, signing certificate fingerprint, and any required cabinet source link are live.
