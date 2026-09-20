fp=r'c:\flutter_windows_3.44.8-stable\Talog20\talog20\lib\main.dart'
with open(fp,'r',encoding='utf-8') as f:
 txt=f.read()
ok=0
nl=chr(10)
s4=' '*4
s6=' '*6
s8=' '*8
# C1 _StaffTasksPanelState
b=txt.find('_StaffTasksPanelState')
w=txt[b:b+500]
c1o=s4+'refresh();'+nl+s4+'channel = DashboardService(supabase).watchTable('
c1n=s4+'future = DashboardService(supabase).fetchTodos();'+nl+s4+'channel = DashboardService(supabase).watchTable('
if c1o in w:
 txt=txt[:b]+w.replace(c1o,c1n,1)+txt[b+500:]
 ok+=1;print('C1 OK')
else:
 print('C1 MISS',repr(c1o))
# C2
b2=txt.find('_StaffSubmissionsPanelState')
w2=txt[b2:b2+600]
c2base=s4+'refresh();'+nl+s4+'final service = DashboardService(supabase);'
c2tail=nl+s4+'channels = ['+nl+s6+'service.watchTable('
c2cname=nl+s8+chr(39)+'staff-submissions-'+chr(36)+'{identityHashCode(this)}'+chr(39)+chr(44)
c2o=c2base+c2tail+c2cname
c2newbase=s4+'future = DashboardService(supabase).fetchStaffSubmissions();'+nl+s4+'final service = DashboardService(supabase);'
c2n=c2newbase+c2tail+c2cname
if c2o in w2:
 txt=txt[:b2]+w2.replace(c2o,c2n,1)+txt[b2+600:]
 ok+=1;print('C2 OK')
else:
 print('C2 MISS',repr(c2o))
b2x=txt.find('_StaffSubmissionsPanelState')
print(repr(txt[b2x+200:b2x+450]))
c2cname2=nl+s8+'channelName: '+chr(39)+'staff-submissions-'+chr(36)+'{identityHashCode(this)}'+chr(39)+chr(44)
c2o2=c2base+c2tail+c2cname2
c2n2=c2newbase+c2tail+c2cname2
if c2o2 in w2:
 txt=txt[:b2]+w2.replace(c2o2,c2n2,1)+txt[b2+600:]
 ok+=1;print('C2b OK')
else:
 print('C2b MISS')
# C3 _LiveStaffActivityState
b3=txt.find('_LiveStaffActivityState')
w3=txt[b3:b3+600]
c3base=c2base
c3tail=nl+s4+'channels = ['+nl+s6+'service.watchTable('
c3cname=nl+s8+'channelName: '+chr(39)+'live-update-submissions-'+chr(36)+'{identityHashCode(this)}'+chr(39)+chr(44)
c3o=c3base+c3tail+c3cname
c3n=c2newbase+c3tail+c3cname
if c3o in w3:
 txt=txt[:b3]+w3.replace(c3o,c3n,1)+txt[b3+600:]
 ok+=1;print('C3 OK')
else:
 print('C3 MISS',repr(c3o))
# C4 _AuditLogsPanelState
b4=txt.find('_AuditLogsPanelState')
w4=txt[b4:b4+300]
c4o=s4+'refresh();'+nl+' }'+nl+nl+' void refresh() {'+nl+s4+'setState(() => future = AuthService(supabase).getAuditLogs());'+nl+' }'
c4n=s4+'future = AuthService(supabase).getAuditLogs();'+nl+' }'+nl+nl+' void refresh() {'+nl+s4+'setState(() => future = AuthService(supabase).getAuditLogs());'+nl+' }'
if c4o in w4:
 txt=txt[:b4]+w4.replace(c4o,c4n,1)+txt[b4+300:]
 ok+=1;print('C4 OK')
else:
 print('C4 MISS',repr(c4o))
b4x=txt.find('_AuditLogsPanelState')
print(repr(txt[b4x+100:b4x+300]))
print('c4o hex:',c4o.encode().hex()[:80])
idx=txt.find('_AuditLogsPanelState')
tchk=txt[idx+100:idx+300]
print('txt hex:',tchk.encode().hex()[:80])
s2=' '*2
c4o2=s4+'refresh();'+nl+s2+'}'+nl+nl+s2+'void refresh() {'+nl+s4+'setState(() => future = AuthService(supabase).getAuditLogs());'+nl+s2+'}'
c4n2=s4+'future = AuthService(supabase).getAuditLogs();'+nl+s2+'}'+nl+nl+s2+'void refresh() {'+nl+s4+'setState(() => future = AuthService(supabase).getAuditLogs());'+nl+s2+'}'
if c4o2 in w4:
 txt=txt[:b4]+w4.replace(c4o2,c4n2,1)+txt[b4+300:]
 ok+=1;print('C4 OK')
else:
 print('C4 MISS2',repr(c4o2))
print('b4=',b4,'len w4=',len(w4))
print('c4o2 in full txt:',c4o2 in txt)
# Fix C4 with larger window
w4b=txt[b4:b4+500]
if c4o2 in w4b:
 txt=txt[:b4]+w4b.replace(c4o2,c4n2,1)+txt[b4+500:]
 ok+=1;print('C4b OK')
else:
 print('C4b MISS')
with open(fp,'w',encoding='utf-8') as f:
 f.write(txt)
print(f'DONE: {ok}/4 changes applied, file saved')