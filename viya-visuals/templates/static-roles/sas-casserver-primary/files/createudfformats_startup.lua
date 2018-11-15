--
-- casstartup.lua runs prior to this lua script. 
-- The first time casstartup.lua runs the addFmtLib action fails because
-- the FORMATS caslib does not contains sassuppliedformats.sashdat.

-- The first time this script runs addFmtLib is a SUCCESS and the addFormat 
-- actions are run along with saveFmtlib etc to save sassuppliedformats.sashdat.
--  
-- The 2nd+ time casstartup.lua runs, the addFmtLib actions is a 
-- SUCCESS.
-- The 2nd+ time this script is run, addFmtLib fails and addFormat actions
-- etc are not executed. 
----------------------------------------------------------------------------

local r, info = s:sessionProp_addFmtLib {fmtLibName='SASSuppliedFormats', replace=false}

if info.severity == 0 then  
      
--
-- If addFmtLib is a SUCCESS, run the following code to create the format library
--    
        
s:sessionProp_addFormat { fmtLibName='SASSuppliedFormats',
      fmtName='SHIFT', nStart={1, 2, 2.324, 2.612, 3, 3.324, 3.612, 4, 4.324,
      4.612, 5, 5.324, 5.612, 6, 6.324, 6.612, 7}, nEnd={1.864, 2.324, 2.612,
      2.864, 3.324, 3.612, 3.864, 4.324, 4.612, 4.864, 5.324, 5.612, 5.864,
      6.324, 6.612, 6.864, 7.864}, labels={'3', '2', '1', '2', '2', '1', '2',
      '2', '1', '2', '2', '1', '2', '2', '1', '2', '3'}, otherLab='X',
      notSorted=false, multiLabel=false, fuzz=1E-12, minL=1, maxL=40,
      defaultL=1, excl={8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8},
      replace=true}  
s:sessionProp_addFormat { fmtLibName='SASSuppliedFormats',
      fmtName='SHIFTTXT', nStart={1, 2, 2.324, 2.612, 3, 3.324, 3.612, 4,
      4.324, 4.612, 5, 5.324, 5.612, 6, 6.324, 6.612, 7}, nEnd={1.864, 2.324,
      2.612, 2.864, 3.324, 3.612, 3.864, 4.324, 4.612, 4.864, 5.324, 5.612,
      5.864, 6.324, 6.612, 6.864, 7.864}, labels={'WEEKEND', 'OFFHOUR',
      'PRIMETIME', 'OFFHOUR', 'OFFHOUR', 'PRIMETIME', 'OFFHOUR', 'OFFHOUR',
      'PRIMETIME', 'OFFHOUR', 'OFFHOUR', 'PRIMETIME', 'OFFHOUR', 'OFFHOUR',
      'PRIMETIME', 'OFFHOUR', 'WEEKEND'}, otherLab='UNDEFINED',
      notSorted=false, multiLabel=false, fuzz=1E-12, minL=1, maxL=40,
      defaultL=9, excl={8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8},
      replace=true} 
s:sessionProp_addFormat { fmtLibName='SASSuppliedFormats',
      fmtName='$OBFSUSR', cStart={'bosoutldap.fyi.sas.com',
      'castest5ldap.fyi.sas.com', 'mecornldap.fyi.sas.com',
      'sasdmpldap.fyi.sas.com', 'sasmkgldap.fyi.sas.com'},
      cEnd={'bosoutldap.fyi.sas.com', 'castest5ldap.fyi.sas.com',
      'mecornldap.fyi.sas.com', 'sasdmpldap.fyi.sas.com',
      'sasmkgldap.fyi.sas.com'},
      labels={'1306DB555AD9F7AE2895294E40D9763A72D89590F7E2DA45ED237411EDFE9D03', 
      '80F98C00C3D96A076B1701005E59E0D7858E59C7A5579199AF69407FD7B3BBC5',
      'B822624AFF6E8313212FDD861EAE46AA12E60CAA661BAB3842F818D52B94A8D2',
      '956F5685750C5C33D31AC8A593FF286913CA7524883B6D9A4C2136B4376C8A18',
      '9D5B7A3BE7B3DEBB8CA5A051084EC3FC10B2488DDB0958D3F1ACB5F9BCB8C9E2'},
      otherLab='UNKNOWN VALUE', notSorted=false, multiLabel=false, fuzz=0,
      minL=1, maxL=64, defaultL=64, excl={0, 0, 0, 0, 0}, replace=true   }
s:sessionProp_addFormat { fmtLibName='SASSuppliedFormats',
      fmtName='$SHIFT2TXT', cStart={'1', '2', '3', 'X'}, cEnd={'1', '2', '3',
      'X'}, labels={'PRIMETIME', 'OFFHOUR', 'WEEKEND', 'UNDEFINED'},
      notSorted=false, multiLabel=false, fuzz=0, minL=1, maxL=40, defaultL=9,
      excl={0, 0, 0, 0}, replace=true}  
s:sessionProp_addFormat { fmtLibName='SASSuppliedFormats',
      fmtName='$SHIFTXT2ID', cStart={'OFFHOUR', 'PRIMETIME', 'UNDEFINED',
      'WEEKEND'}, cEnd={'OFFHOUR', 'PRIMETIME', 'UNDEFINED', 'WEEKEND'},
      labels={'2', '1', 'X', '3'}, notSorted=false, multiLabel=false, fuzz=0,
      minL=1, maxL=40, defaultL=1, excl={0, 0, 0, 0}, replace=true} 
s:sessionProp_saveFmtLib { fmtLibName='SASSUPPLIEDFORMATS',
      caslib='Formats', name='sassuppliedformats',
      replace=true, promote=false}
s:sessionProp_promoteFmtLib {fmtLibName='SASSUPPLIEDFORMATS', replace=true}

end

