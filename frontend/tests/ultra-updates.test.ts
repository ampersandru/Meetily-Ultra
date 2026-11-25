import { expect, mock, test } from 'bun:test';
let updaterCalls=0;
mock.module('@tauri-apps/plugin-updater',()=>({check:async()=>{updaterCalls++; throw new Error('Upstream feed must never be queried');}}));
mock.module('@tauri-apps/api/app',()=>({getVersion:async()=>'0.3.0'}));
const {UpdateService}=await import('../src/services/updateService');
test('Ultra manual updates never contact the inherited automatic updater, including forced checks',async()=>{
 const service=new UpdateService();
 expect(await service.checkForUpdates()).toEqual({available:false,currentVersion:'0.3.0'});
 expect(await service.checkForUpdates(true)).toEqual({available:false,currentVersion:'0.3.0'});
 expect(updaterCalls).toBe(0);
});
