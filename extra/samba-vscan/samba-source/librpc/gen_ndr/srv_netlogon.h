#include "../librpc/gen_ndr/ndr_netlogon.h"
#ifndef __SRV_NETLOGON__
#define __SRV_NETLOGON__
WERROR _netr_LogonUasLogon(pipes_struct *p, struct netr_LogonUasLogon *r);
WERROR _netr_LogonUasLogoff(pipes_struct *p, struct netr_LogonUasLogoff *r);
NTSTATUS _netr_LogonSamLogon(pipes_struct *p, struct netr_LogonSamLogon *r);
NTSTATUS _netr_LogonSamLogoff(pipes_struct *p, struct netr_LogonSamLogoff *r);
NTSTATUS _netr_ServerReqChallenge(pipes_struct *p, struct netr_ServerReqChallenge *r);
NTSTATUS _netr_ServerAuthenticate(pipes_struct *p, struct netr_ServerAuthenticate *r);
NTSTATUS _netr_ServerPasswordSet(pipes_struct *p, struct netr_ServerPasswordSet *r);
NTSTATUS _netr_DatabaseDeltas(pipes_struct *p, struct netr_DatabaseDeltas *r);
NTSTATUS _netr_DatabaseSync(pipes_struct *p, struct netr_DatabaseSync *r);
NTSTATUS _netr_AccountDeltas(pipes_struct *p, struct netr_AccountDeltas *r);
NTSTATUS _netr_AccountSync(pipes_struct *p, struct netr_AccountSync *r);
WERROR _netr_GetDcName(pipes_struct *p, struct netr_GetDcName *r);
WERROR _netr_LogonControl(pipes_struct *p, struct netr_LogonControl *r);
WERROR _netr_GetAnyDCName(pipes_struct *p, struct netr_GetAnyDCName *r);
WERROR _netr_LogonControl2(pipes_struct *p, struct netr_LogonControl2 *r);
NTSTATUS _netr_ServerAuthenticate2(pipes_struct *p, struct netr_ServerAuthenticate2 *r);
NTSTATUS _netr_DatabaseSync2(pipes_struct *p, struct netr_DatabaseSync2 *r);
NTSTATUS _netr_DatabaseRedo(pipes_struct *p, struct netr_DatabaseRedo *r);
WERROR _netr_LogonControl2Ex(pipes_struct *p, struct netr_LogonControl2Ex *r);
WERROR _netr_NetrEnumerateTrustedDomains(pipes_struct *p, struct netr_NetrEnumerateTrustedDomains *r);
WERROR _netr_DsRGetDCName(pipes_struct *p, struct netr_DsRGetDCName *r);
NTSTATUS _netr_LogonGetCapabilities(pipes_struct *p, struct netr_LogonGetCapabilities *r);
WERROR _netr_NETRLOGONSETSERVICEBITS(pipes_struct *p, struct netr_NETRLOGONSETSERVICEBITS *r);
WERROR _netr_LogonGetTrustRid(pipes_struct *p, struct netr_LogonGetTrustRid *r);
WERROR _netr_NETRLOGONCOMPUTESERVERDIGEST(pipes_struct *p, struct netr_NETRLOGONCOMPUTESERVERDIGEST *r);
WERROR _netr_NETRLOGONCOMPUTECLIENTDIGEST(pipes_struct *p, struct netr_NETRLOGONCOMPUTECLIENTDIGEST *r);
NTSTATUS _netr_ServerAuthenticate3(pipes_struct *p, struct netr_ServerAuthenticate3 *r);
WERROR _netr_DsRGetDCNameEx(pipes_struct *p, struct netr_DsRGetDCNameEx *r);
WERROR _netr_DsRGetSiteName(pipes_struct *p, struct netr_DsRGetSiteName *r);
NTSTATUS _netr_LogonGetDomainInfo(pipes_struct *p, struct netr_LogonGetDomainInfo *r);
NTSTATUS _netr_ServerPasswordSet2(pipes_struct *p, struct netr_ServerPasswordSet2 *r);
WERROR _netr_ServerPasswordGet(pipes_struct *p, struct netr_ServerPasswordGet *r);
WERROR _netr_NETRLOGONSENDTOSAM(pipes_struct *p, struct netr_NETRLOGONSENDTOSAM *r);
WERROR _netr_DsRAddressToSitenamesW(pipes_struct *p, struct netr_DsRAddressToSitenamesW *r);
WERROR _netr_DsRGetDCNameEx2(pipes_struct *p, struct netr_DsRGetDCNameEx2 *r);
WERROR _netr_NETRLOGONGETTIMESERVICEPARENTDOMAIN(pipes_struct *p, struct netr_NETRLOGONGETTIMESERVICEPARENTDOMAIN *r);
WERROR _netr_NetrEnumerateTrustedDomainsEx(pipes_struct *p, struct netr_NetrEnumerateTrustedDomainsEx *r);
WERROR _netr_DsRAddressToSitenamesExW(pipes_struct *p, struct netr_DsRAddressToSitenamesExW *r);
WERROR _netr_DsrGetDcSiteCoverageW(pipes_struct *p, struct netr_DsrGetDcSiteCoverageW *r);
NTSTATUS _netr_LogonSamLogonEx(pipes_struct *p, struct netr_LogonSamLogonEx *r);
WERROR _netr_DsrEnumerateDomainTrusts(pipes_struct *p, struct netr_DsrEnumerateDomainTrusts *r);
WERROR _netr_DsrDeregisterDNSHostRecords(pipes_struct *p, struct netr_DsrDeregisterDNSHostRecords *r);
NTSTATUS _netr_ServerTrustPasswordsGet(pipes_struct *p, struct netr_ServerTrustPasswordsGet *r);
WERROR _netr_DsRGetForestTrustInformation(pipes_struct *p, struct netr_DsRGetForestTrustInformation *r);
WERROR _netr_GetForestTrustInformation(pipes_struct *p, struct netr_GetForestTrustInformation *r);
NTSTATUS _netr_LogonSamLogonWithFlags(pipes_struct *p, struct netr_LogonSamLogonWithFlags *r);
NTSTATUS _netr_ServerGetTrustInfo(pipes_struct *p, struct netr_ServerGetTrustInfo *r);
void netlogon_get_pipe_fns(struct api_struct **fns, int *n_fns);
NTSTATUS rpc_netlogon_dispatch(struct rpc_pipe_client *cli, TALLOC_CTX *mem_ctx, const struct ndr_interface_table *table, uint32_t opnum, void *r);
WERROR _netr_LogonUasLogon(pipes_struct *p, struct netr_LogonUasLogon *r);
WERROR _netr_LogonUasLogoff(pipes_struct *p, struct netr_LogonUasLogoff *r);
NTSTATUS _netr_LogonSamLogon(pipes_struct *p, struct netr_LogonSamLogon *r);
NTSTATUS _netr_LogonSamLogoff(pipes_struct *p, struct netr_LogonSamLogoff *r);
NTSTATUS _netr_ServerReqChallenge(pipes_struct *p, struct netr_ServerReqChallenge *r);
NTSTATUS _netr_ServerAuthenticate(pipes_struct *p, struct netr_ServerAuthenticate *r);
NTSTATUS _netr_ServerPasswordSet(pipes_struct *p, struct netr_ServerPasswordSet *r);
NTSTATUS _netr_DatabaseDeltas(pipes_struct *p, struct netr_DatabaseDeltas *r);
NTSTATUS _netr_DatabaseSync(pipes_struct *p, struct netr_DatabaseSync *r);
NTSTATUS _netr_AccountDeltas(pipes_struct *p, struct netr_AccountDeltas *r);
NTSTATUS _netr_AccountSync(pipes_struct *p, struct netr_AccountSync *r);
WERROR _netr_GetDcName(pipes_struct *p, struct netr_GetDcName *r);
WERROR _netr_LogonControl(pipes_struct *p, struct netr_LogonControl *r);
WERROR _netr_GetAnyDCName(pipes_struct *p, struct netr_GetAnyDCName *r);
WERROR _netr_LogonControl2(pipes_struct *p, struct netr_LogonControl2 *r);
NTSTATUS _netr_ServerAuthenticate2(pipes_struct *p, struct netr_ServerAuthenticate2 *r);
NTSTATUS _netr_DatabaseSync2(pipes_struct *p, struct netr_DatabaseSync2 *r);
NTSTATUS _netr_DatabaseRedo(pipes_struct *p, struct netr_DatabaseRedo *r);
WERROR _netr_LogonControl2Ex(pipes_struct *p, struct netr_LogonControl2Ex *r);
WERROR _netr_NetrEnumerateTrustedDomains(pipes_struct *p, struct netr_NetrEnumerateTrustedDomains *r);
WERROR _netr_DsRGetDCName(pipes_struct *p, struct netr_DsRGetDCName *r);
NTSTATUS _netr_LogonGetCapabilities(pipes_struct *p, struct netr_LogonGetCapabilities *r);
WERROR _netr_NETRLOGONSETSERVICEBITS(pipes_struct *p, struct netr_NETRLOGONSETSERVICEBITS *r);
WERROR _netr_LogonGetTrustRid(pipes_struct *p, struct netr_LogonGetTrustRid *r);
WERROR _netr_NETRLOGONCOMPUTESERVERDIGEST(pipes_struct *p, struct netr_NETRLOGONCOMPUTESERVERDIGEST *r);
WERROR _netr_NETRLOGONCOMPUTECLIENTDIGEST(pipes_struct *p, struct netr_NETRLOGONCOMPUTECLIENTDIGEST *r);
NTSTATUS _netr_ServerAuthenticate3(pipes_struct *p, struct netr_ServerAuthenticate3 *r);
WERROR _netr_DsRGetDCNameEx(pipes_struct *p, struct netr_DsRGetDCNameEx *r);
WERROR _netr_DsRGetSiteName(pipes_struct *p, struct netr_DsRGetSiteName *r);
NTSTATUS _netr_LogonGetDomainInfo(pipes_struct *p, struct netr_LogonGetDomainInfo *r);
NTSTATUS _netr_ServerPasswordSet2(pipes_struct *p, struct netr_ServerPasswordSet2 *r);
WERROR _netr_ServerPasswordGet(pipes_struct *p, struct netr_ServerPasswordGet *r);
WERROR _netr_NETRLOGONSENDTOSAM(pipes_struct *p, struct netr_NETRLOGONSENDTOSAM *r);
WERROR _netr_DsRAddressToSitenamesW(pipes_struct *p, struct netr_DsRAddressToSitenamesW *r);
WERROR _netr_DsRGetDCNameEx2(pipes_struct *p, struct netr_DsRGetDCNameEx2 *r);
WERROR _netr_NETRLOGONGETTIMESERVICEPARENTDOMAIN(pipes_struct *p, struct netr_NETRLOGONGETTIMESERVICEPARENTDOMAIN *r);
WERROR _netr_NetrEnumerateTrustedDomainsEx(pipes_struct *p, struct netr_NetrEnumerateTrustedDomainsEx *r);
WERROR _netr_DsRAddressToSitenamesExW(pipes_struct *p, struct netr_DsRAddressToSitenamesExW *r);
WERROR _netr_DsrGetDcSiteCoverageW(pipes_struct *p, struct netr_DsrGetDcSiteCoverageW *r);
NTSTATUS _netr_LogonSamLogonEx(pipes_struct *p, struct netr_LogonSamLogonEx *r);
WERROR _netr_DsrEnumerateDomainTrusts(pipes_struct *p, struct netr_DsrEnumerateDomainTrusts *r);
WERROR _netr_DsrDeregisterDNSHostRecords(pipes_struct *p, struct netr_DsrDeregisterDNSHostRecords *r);
NTSTATUS _netr_ServerTrustPasswordsGet(pipes_struct *p, struct netr_ServerTrustPasswordsGet *r);
WERROR _netr_DsRGetForestTrustInformation(pipes_struct *p, struct netr_DsRGetForestTrustInformation *r);
WERROR _netr_GetForestTrustInformation(pipes_struct *p, struct netr_GetForestTrustInformation *r);
NTSTATUS _netr_LogonSamLogonWithFlags(pipes_struct *p, struct netr_LogonSamLogonWithFlags *r);
NTSTATUS _netr_ServerGetTrustInfo(pipes_struct *p, struct netr_ServerGetTrustInfo *r);
NTSTATUS rpc_netlogon_init(void);
#endif /* __SRV_NETLOGON__ */
