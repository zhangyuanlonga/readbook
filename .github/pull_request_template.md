## Storage Governance Checklist

- [ ] This change adds no new large JSON payloads to `SharedPreferences`
- [ ] If new persistence is added, I documented why it belongs in `SharedPreferences` / database / managed files / cache / secure storage
- [ ] If files are added, they are not user assets written into a cache or temporary directory
- [ ] If cache behavior is added or changed, I documented key rules, rebuildability, budget, and clear boundary
- [ ] If sensitive data is added or changed, it uses `flutter_secure_storage`
- [ ] If migration is involved, the change follows `old+new read -> new write -> migrate -> remove old structure`
- [ ] If startup logic is added or changed, it does not introduce high-risk automatic cleanup
