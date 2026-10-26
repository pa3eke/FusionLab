import Foundation
import Security
import LocalAuthentication

protocol DMRPasswordStorage {
 func read(for id:String)->String?
 func save(_ password:String,for id:String)->Bool
 func remove(for id:String)
}

struct DMRPasswordStore:DMRPasswordStorage {
 private static func query(_ id:String)->[String:Any] {
  [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"nl.pa3eke.FusionLab.BrandMeister",kSecAttrAccount as String:id]
 }
 func read(for id:String)->String? {
  var q=Self.query(id);q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne
  let context=LAContext();context.interactionNotAllowed=true
  q[kSecUseAuthenticationContext as String]=context
  var result:CFTypeRef?
  guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess,let data=result as? Data else{return nil}
  return String(data:data,encoding:.utf8)
 }
 func save(_ password:String,for id:String)->Bool {
  let q=Self.query(id),value=[kSecValueData as String:Data(password.utf8)]
  let status=SecItemUpdate(q as CFDictionary,value as CFDictionary)
  if status==errSecSuccess{return true}
  guard status==errSecItemNotFound else{return false}
  var item=q;item[kSecValueData as String]=Data(password.utf8)
  item[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  return SecItemAdd(item as CFDictionary,nil)==errSecSuccess
 }
 func remove(for id:String){SecItemDelete(Self.query(id) as CFDictionary)}
}
