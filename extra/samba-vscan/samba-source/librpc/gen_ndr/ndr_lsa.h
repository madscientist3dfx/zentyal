/* header auto-generated by pidl */

#include "librpc/ndr/libndr.h"
#include "../librpc/gen_ndr/lsa.h"

#ifndef _HEADER_NDR_lsarpc
#define _HEADER_NDR_lsarpc

#define NDR_LSARPC_UUID "12345778-1234-abcd-ef00-0123456789ab"
#define NDR_LSARPC_VERSION 0.0
#define NDR_LSARPC_NAME "lsarpc"
#define NDR_LSARPC_HELPSTRING "Local Security Authority"
extern const struct ndr_interface_table ndr_table_lsarpc;
#define NDR_LSA_CLOSE (0x00)

#define NDR_LSA_DELETE (0x01)

#define NDR_LSA_ENUMPRIVS (0x02)

#define NDR_LSA_QUERYSECURITY (0x03)

#define NDR_LSA_SETSECOBJ (0x04)

#define NDR_LSA_CHANGEPASSWORD (0x05)

#define NDR_LSA_OPENPOLICY (0x06)

#define NDR_LSA_QUERYINFOPOLICY (0x07)

#define NDR_LSA_SETINFOPOLICY (0x08)

#define NDR_LSA_CLEARAUDITLOG (0x09)

#define NDR_LSA_CREATEACCOUNT (0x0a)

#define NDR_LSA_ENUMACCOUNTS (0x0b)

#define NDR_LSA_CREATETRUSTEDDOMAIN (0x0c)

#define NDR_LSA_ENUMTRUSTDOM (0x0d)

#define NDR_LSA_LOOKUPNAMES (0x0e)

#define NDR_LSA_LOOKUPSIDS (0x0f)

#define NDR_LSA_CREATESECRET (0x10)

#define NDR_LSA_OPENACCOUNT (0x11)

#define NDR_LSA_ENUMPRIVSACCOUNT (0x12)

#define NDR_LSA_ADDPRIVILEGESTOACCOUNT (0x13)

#define NDR_LSA_REMOVEPRIVILEGESFROMACCOUNT (0x14)

#define NDR_LSA_GETQUOTASFORACCOUNT (0x15)

#define NDR_LSA_SETQUOTASFORACCOUNT (0x16)

#define NDR_LSA_GETSYSTEMACCESSACCOUNT (0x17)

#define NDR_LSA_SETSYSTEMACCESSACCOUNT (0x18)

#define NDR_LSA_OPENTRUSTEDDOMAIN (0x19)

#define NDR_LSA_QUERYTRUSTEDDOMAININFO (0x1a)

#define NDR_LSA_SETINFORMATIONTRUSTEDDOMAIN (0x1b)

#define NDR_LSA_OPENSECRET (0x1c)

#define NDR_LSA_SETSECRET (0x1d)

#define NDR_LSA_QUERYSECRET (0x1e)

#define NDR_LSA_LOOKUPPRIVVALUE (0x1f)

#define NDR_LSA_LOOKUPPRIVNAME (0x20)

#define NDR_LSA_LOOKUPPRIVDISPLAYNAME (0x21)

#define NDR_LSA_DELETEOBJECT (0x22)

#define NDR_LSA_ENUMACCOUNTSWITHUSERRIGHT (0x23)

#define NDR_LSA_ENUMACCOUNTRIGHTS (0x24)

#define NDR_LSA_ADDACCOUNTRIGHTS (0x25)

#define NDR_LSA_REMOVEACCOUNTRIGHTS (0x26)

#define NDR_LSA_QUERYTRUSTEDDOMAININFOBYSID (0x27)

#define NDR_LSA_SETTRUSTEDDOMAININFO (0x28)

#define NDR_LSA_DELETETRUSTEDDOMAIN (0x29)

#define NDR_LSA_STOREPRIVATEDATA (0x2a)

#define NDR_LSA_RETRIEVEPRIVATEDATA (0x2b)

#define NDR_LSA_OPENPOLICY2 (0x2c)

#define NDR_LSA_GETUSERNAME (0x2d)

#define NDR_LSA_QUERYINFOPOLICY2 (0x2e)

#define NDR_LSA_SETINFOPOLICY2 (0x2f)

#define NDR_LSA_QUERYTRUSTEDDOMAININFOBYNAME (0x30)

#define NDR_LSA_SETTRUSTEDDOMAININFOBYNAME (0x31)

#define NDR_LSA_ENUMTRUSTEDDOMAINSEX (0x32)

#define NDR_LSA_CREATETRUSTEDDOMAINEX (0x33)

#define NDR_LSA_CLOSETRUSTEDDOMAINEX (0x34)

#define NDR_LSA_QUERYDOMAININFORMATIONPOLICY (0x35)

#define NDR_LSA_SETDOMAININFORMATIONPOLICY (0x36)

#define NDR_LSA_OPENTRUSTEDDOMAINBYNAME (0x37)

#define NDR_LSA_TESTCALL (0x38)

#define NDR_LSA_LOOKUPSIDS2 (0x39)

#define NDR_LSA_LOOKUPNAMES2 (0x3a)

#define NDR_LSA_CREATETRUSTEDDOMAINEX2 (0x3b)

#define NDR_LSA_CREDRWRITE (0x3c)

#define NDR_LSA_CREDRREAD (0x3d)

#define NDR_LSA_CREDRENUMERATE (0x3e)

#define NDR_LSA_CREDRWRITEDOMAINCREDENTIALS (0x3f)

#define NDR_LSA_CREDRREADDOMAINCREDENTIALS (0x40)

#define NDR_LSA_CREDRDELETE (0x41)

#define NDR_LSA_CREDRGETTARGETINFO (0x42)

#define NDR_LSA_CREDRPROFILELOADED (0x43)

#define NDR_LSA_LOOKUPNAMES3 (0x44)

#define NDR_LSA_CREDRGETSESSIONTYPES (0x45)

#define NDR_LSA_LSARREGISTERAUDITEVENT (0x46)

#define NDR_LSA_LSARGENAUDITEVENT (0x47)

#define NDR_LSA_LSARUNREGISTERAUDITEVENT (0x48)

#define NDR_LSA_LSARQUERYFORESTTRUSTINFORMATION (0x49)

#define NDR_LSA_LSARSETFORESTTRUSTINFORMATION (0x4a)

#define NDR_LSA_CREDRRENAME (0x4b)

#define NDR_LSA_LOOKUPSIDS3 (0x4c)

#define NDR_LSA_LOOKUPNAMES4 (0x4d)

#define NDR_LSA_LSAROPENPOLICYSCE (0x4e)

#define NDR_LSA_LSARADTREGISTERSECURITYEVENTSOURCE (0x4f)

#define NDR_LSA_LSARADTUNREGISTERSECURITYEVENTSOURCE (0x50)

#define NDR_LSA_LSARADTREPORTSECURITYEVENT (0x51)

#define NDR_LSARPC_CALL_COUNT (82)
enum ndr_err_code ndr_push_lsa_String(struct ndr_push *ndr, int ndr_flags, const struct lsa_String *r);
enum ndr_err_code ndr_pull_lsa_String(struct ndr_pull *ndr, int ndr_flags, struct lsa_String *r);
void ndr_print_lsa_String(struct ndr_print *ndr, const char *name, const struct lsa_String *r);
enum ndr_err_code ndr_push_lsa_StringLarge(struct ndr_push *ndr, int ndr_flags, const struct lsa_StringLarge *r);
enum ndr_err_code ndr_pull_lsa_StringLarge(struct ndr_pull *ndr, int ndr_flags, struct lsa_StringLarge *r);
void ndr_print_lsa_StringLarge(struct ndr_print *ndr, const char *name, const struct lsa_StringLarge *r);
enum ndr_err_code ndr_push_lsa_Strings(struct ndr_push *ndr, int ndr_flags, const struct lsa_Strings *r);
enum ndr_err_code ndr_pull_lsa_Strings(struct ndr_pull *ndr, int ndr_flags, struct lsa_Strings *r);
void ndr_print_lsa_Strings(struct ndr_print *ndr, const char *name, const struct lsa_Strings *r);
enum ndr_err_code ndr_push_lsa_AsciiString(struct ndr_push *ndr, int ndr_flags, const struct lsa_AsciiString *r);
enum ndr_err_code ndr_pull_lsa_AsciiString(struct ndr_pull *ndr, int ndr_flags, struct lsa_AsciiString *r);
void ndr_print_lsa_AsciiString(struct ndr_print *ndr, const char *name, const struct lsa_AsciiString *r);
enum ndr_err_code ndr_push_lsa_AsciiStringLarge(struct ndr_push *ndr, int ndr_flags, const struct lsa_AsciiStringLarge *r);
enum ndr_err_code ndr_pull_lsa_AsciiStringLarge(struct ndr_pull *ndr, int ndr_flags, struct lsa_AsciiStringLarge *r);
void ndr_print_lsa_AsciiStringLarge(struct ndr_print *ndr, const char *name, const struct lsa_AsciiStringLarge *r);
enum ndr_err_code ndr_push_lsa_BinaryString(struct ndr_push *ndr, int ndr_flags, const struct lsa_BinaryString *r);
enum ndr_err_code ndr_pull_lsa_BinaryString(struct ndr_pull *ndr, int ndr_flags, struct lsa_BinaryString *r);
void ndr_print_lsa_BinaryString(struct ndr_print *ndr, const char *name, const struct lsa_BinaryString *r);
void ndr_print_lsa_LUID(struct ndr_print *ndr, const char *name, const struct lsa_LUID *r);
void ndr_print_lsa_PrivEntry(struct ndr_print *ndr, const char *name, const struct lsa_PrivEntry *r);
void ndr_print_lsa_PrivArray(struct ndr_print *ndr, const char *name, const struct lsa_PrivArray *r);
void ndr_print_lsa_QosInfo(struct ndr_print *ndr, const char *name, const struct lsa_QosInfo *r);
void ndr_print_lsa_ObjectAttribute(struct ndr_print *ndr, const char *name, const struct lsa_ObjectAttribute *r);
enum ndr_err_code ndr_push_lsa_PolicyAccessMask(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_PolicyAccessMask(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_PolicyAccessMask(struct ndr_print *ndr, const char *name, uint32_t r);
enum ndr_err_code ndr_push_lsa_AccountAccessMask(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_AccountAccessMask(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_AccountAccessMask(struct ndr_print *ndr, const char *name, uint32_t r);
enum ndr_err_code ndr_push_lsa_SecretAccessMask(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_SecretAccessMask(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_SecretAccessMask(struct ndr_print *ndr, const char *name, uint32_t r);
enum ndr_err_code ndr_push_lsa_TrustedAccessMask(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_TrustedAccessMask(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_TrustedAccessMask(struct ndr_print *ndr, const char *name, uint32_t r);
void ndr_print_lsa_AuditLogInfo(struct ndr_print *ndr, const char *name, const struct lsa_AuditLogInfo *r);
void ndr_print_lsa_PolicyAuditPolicy(struct ndr_print *ndr, const char *name, enum lsa_PolicyAuditPolicy r);
void ndr_print_lsa_AuditEventsInfo(struct ndr_print *ndr, const char *name, const struct lsa_AuditEventsInfo *r);
void ndr_print_lsa_DomainInfo(struct ndr_print *ndr, const char *name, const struct lsa_DomainInfo *r);
void ndr_print_lsa_PDAccountInfo(struct ndr_print *ndr, const char *name, const struct lsa_PDAccountInfo *r);
void ndr_print_lsa_Role(struct ndr_print *ndr, const char *name, enum lsa_Role r);
void ndr_print_lsa_ServerRole(struct ndr_print *ndr, const char *name, const struct lsa_ServerRole *r);
void ndr_print_lsa_ReplicaSourceInfo(struct ndr_print *ndr, const char *name, const struct lsa_ReplicaSourceInfo *r);
void ndr_print_lsa_DefaultQuotaInfo(struct ndr_print *ndr, const char *name, const struct lsa_DefaultQuotaInfo *r);
void ndr_print_lsa_ModificationInfo(struct ndr_print *ndr, const char *name, const struct lsa_ModificationInfo *r);
void ndr_print_lsa_AuditFullSetInfo(struct ndr_print *ndr, const char *name, const struct lsa_AuditFullSetInfo *r);
void ndr_print_lsa_AuditFullQueryInfo(struct ndr_print *ndr, const char *name, const struct lsa_AuditFullQueryInfo *r);
void ndr_print_lsa_DnsDomainInfo(struct ndr_print *ndr, const char *name, const struct lsa_DnsDomainInfo *r);
void ndr_print_lsa_PolicyInfo(struct ndr_print *ndr, const char *name, enum lsa_PolicyInfo r);
void ndr_print_lsa_PolicyInformation(struct ndr_print *ndr, const char *name, const union lsa_PolicyInformation *r);
void ndr_print_lsa_SidPtr(struct ndr_print *ndr, const char *name, const struct lsa_SidPtr *r);
enum ndr_err_code ndr_push_lsa_SidArray(struct ndr_push *ndr, int ndr_flags, const struct lsa_SidArray *r);
enum ndr_err_code ndr_pull_lsa_SidArray(struct ndr_pull *ndr, int ndr_flags, struct lsa_SidArray *r);
void ndr_print_lsa_SidArray(struct ndr_print *ndr, const char *name, const struct lsa_SidArray *r);
void ndr_print_lsa_DomainList(struct ndr_print *ndr, const char *name, const struct lsa_DomainList *r);
enum ndr_err_code ndr_push_lsa_SidType(struct ndr_push *ndr, int ndr_flags, enum lsa_SidType r);
enum ndr_err_code ndr_pull_lsa_SidType(struct ndr_pull *ndr, int ndr_flags, enum lsa_SidType *r);
void ndr_print_lsa_SidType(struct ndr_print *ndr, const char *name, enum lsa_SidType r);
void ndr_print_lsa_TranslatedSid(struct ndr_print *ndr, const char *name, const struct lsa_TranslatedSid *r);
void ndr_print_lsa_TransSidArray(struct ndr_print *ndr, const char *name, const struct lsa_TransSidArray *r);
void ndr_print_lsa_RefDomainList(struct ndr_print *ndr, const char *name, const struct lsa_RefDomainList *r);
void ndr_print_lsa_LookupNamesLevel(struct ndr_print *ndr, const char *name, enum lsa_LookupNamesLevel r);
void ndr_print_lsa_TranslatedName(struct ndr_print *ndr, const char *name, const struct lsa_TranslatedName *r);
void ndr_print_lsa_TransNameArray(struct ndr_print *ndr, const char *name, const struct lsa_TransNameArray *r);
void ndr_print_lsa_LUIDAttribute(struct ndr_print *ndr, const char *name, const struct lsa_LUIDAttribute *r);
void ndr_print_lsa_PrivilegeSet(struct ndr_print *ndr, const char *name, const struct lsa_PrivilegeSet *r);
void ndr_print_lsa_DATA_BUF(struct ndr_print *ndr, const char *name, const struct lsa_DATA_BUF *r);
void ndr_print_lsa_DATA_BUF2(struct ndr_print *ndr, const char *name, const struct lsa_DATA_BUF2 *r);
void ndr_print_lsa_TrustDomInfoEnum(struct ndr_print *ndr, const char *name, enum lsa_TrustDomInfoEnum r);
enum ndr_err_code ndr_push_lsa_TrustDirection(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_TrustDirection(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_TrustDirection(struct ndr_print *ndr, const char *name, uint32_t r);
void ndr_print_lsa_TrustType(struct ndr_print *ndr, const char *name, enum lsa_TrustType r);
enum ndr_err_code ndr_push_lsa_TrustAttributes(struct ndr_push *ndr, int ndr_flags, uint32_t r);
enum ndr_err_code ndr_pull_lsa_TrustAttributes(struct ndr_pull *ndr, int ndr_flags, uint32_t *r);
void ndr_print_lsa_TrustAttributes(struct ndr_print *ndr, const char *name, uint32_t r);
void ndr_print_lsa_TrustDomainInfoName(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoName *r);
void ndr_print_lsa_TrustDomainInfoControllers(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoControllers *r);
void ndr_print_lsa_TrustDomainInfoPosixOffset(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoPosixOffset *r);
void ndr_print_lsa_TrustDomainInfoPassword(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoPassword *r);
void ndr_print_lsa_TrustDomainInfoBasic(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoBasic *r);
void ndr_print_lsa_TrustDomainInfoInfoEx(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoInfoEx *r);
enum ndr_err_code ndr_push_lsa_TrustAuthType(struct ndr_push *ndr, int ndr_flags, enum lsa_TrustAuthType r);
enum ndr_err_code ndr_pull_lsa_TrustAuthType(struct ndr_pull *ndr, int ndr_flags, enum lsa_TrustAuthType *r);
void ndr_print_lsa_TrustAuthType(struct ndr_print *ndr, const char *name, enum lsa_TrustAuthType r);
void ndr_print_lsa_TrustDomainInfoBuffer(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoBuffer *r);
void ndr_print_lsa_TrustDomainInfoAuthInfo(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoAuthInfo *r);
void ndr_print_lsa_TrustDomainInfoFullInfo(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoFullInfo *r);
void ndr_print_lsa_TrustDomainInfoAuthInfoInternal(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoAuthInfoInternal *r);
void ndr_print_lsa_TrustDomainInfoFullInfoInternal(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoFullInfoInternal *r);
void ndr_print_lsa_TrustDomainInfoInfoEx2Internal(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoInfoEx2Internal *r);
void ndr_print_lsa_TrustDomainInfoFullInfo2Internal(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoFullInfo2Internal *r);
void ndr_print_lsa_TrustDomainInfoSupportedEncTypes(struct ndr_print *ndr, const char *name, const struct lsa_TrustDomainInfoSupportedEncTypes *r);
void ndr_print_lsa_TrustedDomainInfo(struct ndr_print *ndr, const char *name, const union lsa_TrustedDomainInfo *r);
void ndr_print_lsa_DATA_BUF_PTR(struct ndr_print *ndr, const char *name, const struct lsa_DATA_BUF_PTR *r);
void ndr_print_lsa_RightSet(struct ndr_print *ndr, const char *name, const struct lsa_RightSet *r);
void ndr_print_lsa_DomainListEx(struct ndr_print *ndr, const char *name, const struct lsa_DomainListEx *r);
void ndr_print_lsa_DomainInfoKerberos(struct ndr_print *ndr, const char *name, const struct lsa_DomainInfoKerberos *r);
void ndr_print_lsa_DomainInfoEfs(struct ndr_print *ndr, const char *name, const struct lsa_DomainInfoEfs *r);
void ndr_print_lsa_DomainInformationPolicy(struct ndr_print *ndr, const char *name, const union lsa_DomainInformationPolicy *r);
void ndr_print_lsa_TranslatedName2(struct ndr_print *ndr, const char *name, const struct lsa_TranslatedName2 *r);
void ndr_print_lsa_TransNameArray2(struct ndr_print *ndr, const char *name, const struct lsa_TransNameArray2 *r);
void ndr_print_lsa_TranslatedSid2(struct ndr_print *ndr, const char *name, const struct lsa_TranslatedSid2 *r);
void ndr_print_lsa_TransSidArray2(struct ndr_print *ndr, const char *name, const struct lsa_TransSidArray2 *r);
void ndr_print_lsa_TranslatedSid3(struct ndr_print *ndr, const char *name, const struct lsa_TranslatedSid3 *r);
void ndr_print_lsa_TransSidArray3(struct ndr_print *ndr, const char *name, const struct lsa_TransSidArray3 *r);
void ndr_print_lsa_ForestTrustBinaryData(struct ndr_print *ndr, const char *name, const struct lsa_ForestTrustBinaryData *r);
void ndr_print_lsa_ForestTrustDomainInfo(struct ndr_print *ndr, const char *name, const struct lsa_ForestTrustDomainInfo *r);
void ndr_print_lsa_ForestTrustData(struct ndr_print *ndr, const char *name, const union lsa_ForestTrustData *r);
void ndr_print_lsa_ForestTrustRecordType(struct ndr_print *ndr, const char *name, enum lsa_ForestTrustRecordType r);
void ndr_print_lsa_ForestTrustRecord(struct ndr_print *ndr, const char *name, const struct lsa_ForestTrustRecord *r);
enum ndr_err_code ndr_push_lsa_ForestTrustInformation(struct ndr_push *ndr, int ndr_flags, const struct lsa_ForestTrustInformation *r);
enum ndr_err_code ndr_pull_lsa_ForestTrustInformation(struct ndr_pull *ndr, int ndr_flags, struct lsa_ForestTrustInformation *r);
void ndr_print_lsa_ForestTrustInformation(struct ndr_print *ndr, const char *name, const struct lsa_ForestTrustInformation *r);
void ndr_print_lsa_Close(struct ndr_print *ndr, const char *name, int flags, const struct lsa_Close *r);
enum ndr_err_code ndr_push_lsa_Delete(struct ndr_push *ndr, int flags, const struct lsa_Delete *r);
enum ndr_err_code ndr_pull_lsa_Delete(struct ndr_pull *ndr, int flags, struct lsa_Delete *r);
void ndr_print_lsa_Delete(struct ndr_print *ndr, const char *name, int flags, const struct lsa_Delete *r);
enum ndr_err_code ndr_push_lsa_EnumPrivs(struct ndr_push *ndr, int flags, const struct lsa_EnumPrivs *r);
enum ndr_err_code ndr_pull_lsa_EnumPrivs(struct ndr_pull *ndr, int flags, struct lsa_EnumPrivs *r);
void ndr_print_lsa_EnumPrivs(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumPrivs *r);
void ndr_print_lsa_QuerySecurity(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QuerySecurity *r);
void ndr_print_lsa_SetSecObj(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetSecObj *r);
void ndr_print_lsa_ChangePassword(struct ndr_print *ndr, const char *name, int flags, const struct lsa_ChangePassword *r);
enum ndr_err_code ndr_push_lsa_OpenPolicy(struct ndr_push *ndr, int flags, const struct lsa_OpenPolicy *r);
enum ndr_err_code ndr_pull_lsa_OpenPolicy(struct ndr_pull *ndr, int flags, struct lsa_OpenPolicy *r);
void ndr_print_lsa_OpenPolicy(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenPolicy *r);
void ndr_print_lsa_QueryInfoPolicy(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryInfoPolicy *r);
void ndr_print_lsa_SetInfoPolicy(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetInfoPolicy *r);
void ndr_print_lsa_ClearAuditLog(struct ndr_print *ndr, const char *name, int flags, const struct lsa_ClearAuditLog *r);
enum ndr_err_code ndr_push_lsa_CreateAccount(struct ndr_push *ndr, int flags, const struct lsa_CreateAccount *r);
enum ndr_err_code ndr_pull_lsa_CreateAccount(struct ndr_pull *ndr, int flags, struct lsa_CreateAccount *r);
void ndr_print_lsa_CreateAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CreateAccount *r);
enum ndr_err_code ndr_push_lsa_EnumAccounts(struct ndr_push *ndr, int flags, const struct lsa_EnumAccounts *r);
enum ndr_err_code ndr_pull_lsa_EnumAccounts(struct ndr_pull *ndr, int flags, struct lsa_EnumAccounts *r);
void ndr_print_lsa_EnumAccounts(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumAccounts *r);
enum ndr_err_code ndr_push_lsa_CreateTrustedDomain(struct ndr_push *ndr, int flags, const struct lsa_CreateTrustedDomain *r);
enum ndr_err_code ndr_pull_lsa_CreateTrustedDomain(struct ndr_pull *ndr, int flags, struct lsa_CreateTrustedDomain *r);
void ndr_print_lsa_CreateTrustedDomain(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CreateTrustedDomain *r);
void ndr_print_lsa_EnumTrustDom(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumTrustDom *r);
enum ndr_err_code ndr_push_lsa_LookupNames(struct ndr_push *ndr, int flags, const struct lsa_LookupNames *r);
enum ndr_err_code ndr_pull_lsa_LookupNames(struct ndr_pull *ndr, int flags, struct lsa_LookupNames *r);
void ndr_print_lsa_LookupNames(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupNames *r);
enum ndr_err_code ndr_push_lsa_LookupSids(struct ndr_push *ndr, int flags, const struct lsa_LookupSids *r);
enum ndr_err_code ndr_pull_lsa_LookupSids(struct ndr_pull *ndr, int flags, struct lsa_LookupSids *r);
void ndr_print_lsa_LookupSids(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupSids *r);
enum ndr_err_code ndr_push_lsa_CreateSecret(struct ndr_push *ndr, int flags, const struct lsa_CreateSecret *r);
enum ndr_err_code ndr_pull_lsa_CreateSecret(struct ndr_pull *ndr, int flags, struct lsa_CreateSecret *r);
void ndr_print_lsa_CreateSecret(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CreateSecret *r);
void ndr_print_lsa_OpenAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenAccount *r);
void ndr_print_lsa_EnumPrivsAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumPrivsAccount *r);
void ndr_print_lsa_AddPrivilegesToAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_AddPrivilegesToAccount *r);
void ndr_print_lsa_RemovePrivilegesFromAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_RemovePrivilegesFromAccount *r);
void ndr_print_lsa_GetQuotasForAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_GetQuotasForAccount *r);
void ndr_print_lsa_SetQuotasForAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetQuotasForAccount *r);
void ndr_print_lsa_GetSystemAccessAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_GetSystemAccessAccount *r);
void ndr_print_lsa_SetSystemAccessAccount(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetSystemAccessAccount *r);
void ndr_print_lsa_OpenTrustedDomain(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenTrustedDomain *r);
void ndr_print_lsa_QueryTrustedDomainInfo(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryTrustedDomainInfo *r);
void ndr_print_lsa_SetInformationTrustedDomain(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetInformationTrustedDomain *r);
enum ndr_err_code ndr_push_lsa_OpenSecret(struct ndr_push *ndr, int flags, const struct lsa_OpenSecret *r);
enum ndr_err_code ndr_pull_lsa_OpenSecret(struct ndr_pull *ndr, int flags, struct lsa_OpenSecret *r);
void ndr_print_lsa_OpenSecret(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenSecret *r);
enum ndr_err_code ndr_push_lsa_SetSecret(struct ndr_push *ndr, int flags, const struct lsa_SetSecret *r);
enum ndr_err_code ndr_pull_lsa_SetSecret(struct ndr_pull *ndr, int flags, struct lsa_SetSecret *r);
void ndr_print_lsa_SetSecret(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetSecret *r);
enum ndr_err_code ndr_push_lsa_QuerySecret(struct ndr_push *ndr, int flags, const struct lsa_QuerySecret *r);
enum ndr_err_code ndr_pull_lsa_QuerySecret(struct ndr_pull *ndr, int flags, struct lsa_QuerySecret *r);
void ndr_print_lsa_QuerySecret(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QuerySecret *r);
void ndr_print_lsa_LookupPrivValue(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupPrivValue *r);
void ndr_print_lsa_LookupPrivName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupPrivName *r);
void ndr_print_lsa_LookupPrivDisplayName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupPrivDisplayName *r);
void ndr_print_lsa_DeleteObject(struct ndr_print *ndr, const char *name, int flags, const struct lsa_DeleteObject *r);
void ndr_print_lsa_EnumAccountsWithUserRight(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumAccountsWithUserRight *r);
void ndr_print_lsa_EnumAccountRights(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumAccountRights *r);
void ndr_print_lsa_AddAccountRights(struct ndr_print *ndr, const char *name, int flags, const struct lsa_AddAccountRights *r);
void ndr_print_lsa_RemoveAccountRights(struct ndr_print *ndr, const char *name, int flags, const struct lsa_RemoveAccountRights *r);
void ndr_print_lsa_QueryTrustedDomainInfoBySid(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryTrustedDomainInfoBySid *r);
void ndr_print_lsa_SetTrustedDomainInfo(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetTrustedDomainInfo *r);
void ndr_print_lsa_DeleteTrustedDomain(struct ndr_print *ndr, const char *name, int flags, const struct lsa_DeleteTrustedDomain *r);
void ndr_print_lsa_StorePrivateData(struct ndr_print *ndr, const char *name, int flags, const struct lsa_StorePrivateData *r);
void ndr_print_lsa_RetrievePrivateData(struct ndr_print *ndr, const char *name, int flags, const struct lsa_RetrievePrivateData *r);
enum ndr_err_code ndr_push_lsa_OpenPolicy2(struct ndr_push *ndr, int flags, const struct lsa_OpenPolicy2 *r);
enum ndr_err_code ndr_pull_lsa_OpenPolicy2(struct ndr_pull *ndr, int flags, struct lsa_OpenPolicy2 *r);
void ndr_print_lsa_OpenPolicy2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenPolicy2 *r);
void ndr_print_lsa_GetUserName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_GetUserName *r);
void ndr_print_lsa_QueryInfoPolicy2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryInfoPolicy2 *r);
void ndr_print_lsa_SetInfoPolicy2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetInfoPolicy2 *r);
void ndr_print_lsa_QueryTrustedDomainInfoByName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryTrustedDomainInfoByName *r);
void ndr_print_lsa_SetTrustedDomainInfoByName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetTrustedDomainInfoByName *r);
void ndr_print_lsa_EnumTrustedDomainsEx(struct ndr_print *ndr, const char *name, int flags, const struct lsa_EnumTrustedDomainsEx *r);
void ndr_print_lsa_CreateTrustedDomainEx(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CreateTrustedDomainEx *r);
void ndr_print_lsa_CloseTrustedDomainEx(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CloseTrustedDomainEx *r);
void ndr_print_lsa_QueryDomainInformationPolicy(struct ndr_print *ndr, const char *name, int flags, const struct lsa_QueryDomainInformationPolicy *r);
void ndr_print_lsa_SetDomainInformationPolicy(struct ndr_print *ndr, const char *name, int flags, const struct lsa_SetDomainInformationPolicy *r);
void ndr_print_lsa_OpenTrustedDomainByName(struct ndr_print *ndr, const char *name, int flags, const struct lsa_OpenTrustedDomainByName *r);
void ndr_print_lsa_TestCall(struct ndr_print *ndr, const char *name, int flags, const struct lsa_TestCall *r);
enum ndr_err_code ndr_push_lsa_LookupSids2(struct ndr_push *ndr, int flags, const struct lsa_LookupSids2 *r);
enum ndr_err_code ndr_pull_lsa_LookupSids2(struct ndr_pull *ndr, int flags, struct lsa_LookupSids2 *r);
void ndr_print_lsa_LookupSids2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupSids2 *r);
enum ndr_err_code ndr_push_lsa_LookupNames2(struct ndr_push *ndr, int flags, const struct lsa_LookupNames2 *r);
enum ndr_err_code ndr_pull_lsa_LookupNames2(struct ndr_pull *ndr, int flags, struct lsa_LookupNames2 *r);
void ndr_print_lsa_LookupNames2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupNames2 *r);
void ndr_print_lsa_CreateTrustedDomainEx2(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CreateTrustedDomainEx2 *r);
void ndr_print_lsa_CREDRWRITE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRWRITE *r);
void ndr_print_lsa_CREDRREAD(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRREAD *r);
void ndr_print_lsa_CREDRENUMERATE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRENUMERATE *r);
void ndr_print_lsa_CREDRWRITEDOMAINCREDENTIALS(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRWRITEDOMAINCREDENTIALS *r);
void ndr_print_lsa_CREDRREADDOMAINCREDENTIALS(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRREADDOMAINCREDENTIALS *r);
void ndr_print_lsa_CREDRDELETE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRDELETE *r);
void ndr_print_lsa_CREDRGETTARGETINFO(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRGETTARGETINFO *r);
void ndr_print_lsa_CREDRPROFILELOADED(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRPROFILELOADED *r);
enum ndr_err_code ndr_push_lsa_LookupNames3(struct ndr_push *ndr, int flags, const struct lsa_LookupNames3 *r);
enum ndr_err_code ndr_pull_lsa_LookupNames3(struct ndr_pull *ndr, int flags, struct lsa_LookupNames3 *r);
void ndr_print_lsa_LookupNames3(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupNames3 *r);
void ndr_print_lsa_CREDRGETSESSIONTYPES(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRGETSESSIONTYPES *r);
void ndr_print_lsa_LSARREGISTERAUDITEVENT(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARREGISTERAUDITEVENT *r);
void ndr_print_lsa_LSARGENAUDITEVENT(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARGENAUDITEVENT *r);
void ndr_print_lsa_LSARUNREGISTERAUDITEVENT(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARUNREGISTERAUDITEVENT *r);
void ndr_print_lsa_lsaRQueryForestTrustInformation(struct ndr_print *ndr, const char *name, int flags, const struct lsa_lsaRQueryForestTrustInformation *r);
void ndr_print_lsa_LSARSETFORESTTRUSTINFORMATION(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARSETFORESTTRUSTINFORMATION *r);
void ndr_print_lsa_CREDRRENAME(struct ndr_print *ndr, const char *name, int flags, const struct lsa_CREDRRENAME *r);
enum ndr_err_code ndr_push_lsa_LookupSids3(struct ndr_push *ndr, int flags, const struct lsa_LookupSids3 *r);
enum ndr_err_code ndr_pull_lsa_LookupSids3(struct ndr_pull *ndr, int flags, struct lsa_LookupSids3 *r);
void ndr_print_lsa_LookupSids3(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupSids3 *r);
void ndr_print_lsa_LookupNames4(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LookupNames4 *r);
void ndr_print_lsa_LSAROPENPOLICYSCE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSAROPENPOLICYSCE *r);
void ndr_print_lsa_LSARADTREGISTERSECURITYEVENTSOURCE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARADTREGISTERSECURITYEVENTSOURCE *r);
void ndr_print_lsa_LSARADTUNREGISTERSECURITYEVENTSOURCE(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARADTUNREGISTERSECURITYEVENTSOURCE *r);
void ndr_print_lsa_LSARADTREPORTSECURITYEVENT(struct ndr_print *ndr, const char *name, int flags, const struct lsa_LSARADTREPORTSECURITYEVENT *r);
#endif /* _HEADER_NDR_lsarpc */
