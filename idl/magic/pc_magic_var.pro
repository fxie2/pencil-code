; $Id: pc_magic_var.pro,v 1.13 2004-12-25 14:41:26 ajohan Exp $
;
;  Author: Tony Mee (A.J.Mee@ncl.ac.uk)
;  $Date: 2004-12-25 14:41:26 $
;  $Revision: 1.13 $
;
;  25-may-04/tony: coded 
;
; Utility routine to automatically constuct expressions for commonly
; requested variable from variables stored in a var file. 
;
; The routine is not really desigend to be called directly
; but rather it is intended as a utility function for other
; routines such as pc_read_var.
;
; Having these shortcuts makes using transformation routines
; like pc_eoscalc that have been written in a very high-level
; general purpose way somewhat less t
;
; See idl/magic/pc_magic_var.pro to view/add useful variables.
; NB the behaviour of pc_read_magic can be dependent upon other parameters etc.
; eg. calculation of pressure is achieved using ss for noionization and lnTT for ionization.
;
;  Examples:
;  A)
;    pc_init
;    pc_read_var,obj=data,variables=['uu','lnrho','bb','tt'],/MAGIC
;
;  Will return (if available) a structure with elements uu, lnrho, bb and
;  tt respectively containing Velocity, Log Density, Magnetic Field and 
;  Temperature fields.
;
;  B)
;    pc_init
;    pc_read_var,obj=mydata,variables=['uu','lnrho','bb','divu','pp'],/MAGIC
;  Is equivalent to:
;    pc_read_var,obj=mydata,variables=['uu','lnrho','curl(aa)','div(uu)', $
;                                       'pc_eoscalc(lnrho,ss,/pp,/lnrho_ss)'], $
;                                 tags=['uu','lnrho','bb','divu','pp'],/MAGIC
;
;  NB. pc_init must be called prior to any possible derivative usage 
;      (e.g. here bb = curl(aa) )
;      
;  Current mappings: 
;
;    bb      -> Magnetic field vector
;    divu    -> Divergence of velocity
;    u2      -> Modulus of velocity
;    cs2     -> Sound speed squared
;    ee      -> Specific energy
;    tt      -> Temperature
;    pp      -> Pressure
;    rhod    -> Dust density
;    fd      -> Dust distribution function dn = f dm
;    ad      -> Dust grain radius
;    epsd    -> Dust-to-gas ratio (sum over all bins)
;    smon    -> Supersaturation level Pmon/Psat
;    unit_md -> Dust mass unit
;    mdave   -> Average grain mass (mean over all bins)
;
;
pro pc_magic_var,variables,tags,param=param,datadir=datadir

  default, datadir, 'data'
; Allow param to be passed it if already loaded (eg. when called from inside another pc_ routine)
  if n_elements(param) eq 0 then pc_read_param,object=param,datadir=datadir

  lionization = safe_get_tag(param,'lionization',default=safe_get_tag(param,'leos_ionization',default=0)) 
  lionization_fixed = safe_get_tag(param,'lionization_fixed',default=safe_get_tag(param,'leos_ionizationi_fixed',default=0)) 

  for iv=0,n_elements(variables)-1 do begin

    ; Magnetic field vector
    if variables[iv] eq 'bb' then begin
      tags[iv]=variables[iv]
      variables[iv]='curl(aa)'

    ; Current density 
    endif else if variables[iv] eq 'jj' then begin
      tags[iv]=variables[iv]
      variables[iv]='curl(curl(aa))'

    ; Vorticity
    endif else if variables[iv] eq 'oo' then begin
      tags[iv]=variables[iv]
      variables[iv]='curl(uu)'

    ; Divergence of velocity
    endif else if variables[iv] eq 'divu' then begin
      tags[iv]=variables[iv]
      variables[iv]='div(uu)'

    ; Advection
    endif else if variables[iv] eq 'adv' then begin
      tags[iv]=variables[iv]
      variables[iv]='0.5*grad(dot2(uu))-cross(uu,curl(uu))'

    ; Modulus of velocity
    endif else if variables[iv] eq 'u2' then begin
      tags[iv]=variables[iv]
      variables[iv]='dot2(uu)'

    ; Sound speed squared
    endif else if variables[iv] eq 'cs2' then begin
      tags[iv]=variables[iv]
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc(lnrho,lnTT,/cs2,/lnrho_lnTT)'
      endif else begin
        variables[iv]='pc_eoscalc(lnrho,ss,/cs2,/lnrho_ss)'
      endelse

    ; Specific energy
    endif else if variables[iv] eq 'ee' then begin
      tags[iv]=variables[iv]
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc(lnrho,lnTT,/ee,/lnrho_lnTT)'
      endif else begin
        variables[iv]='pc_eoscalc(lnrho,ss,/ee,/lnrho_ss)'
      endelse

    ; Temperature
    endif else if variables[iv] eq 'tt' then begin
      tags[iv]=variables[iv]
      if (lionization and not lionization_fixed) then begin
        variables[iv]='exp(lnTT)'
      endif else begin
        variables[iv]='pc_eoscalc(lnrho,ss,/tt,/lnrho_ss)'
      endelse

    ; Pressure
    endif else if variables[iv] eq 'pp' then begin
      tags[iv]=variables[iv]
      if (lionization and not lionization_fixed) then begin
        variables[iv]='pc_eoscalc(lnrho,lnTT,/pp,/lnrho_lnTT)'
      endif else begin
        variables[iv]='pc_eoscalc(lnrho,ss,/pp,/lnrho_ss)'
      endelse

    ; Dust density
    endif else if variables[iv] eq 'rhod' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(nd=nd,md=md,param=param,var='rhod')"

    ; Dust distribution function dn = f dm
    endif else if variables[iv] eq 'fd' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(nd=nd,param=param,var='fd')"

    ; Dust grain radius
    endif else if variables[iv] eq 'ad' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(md=md,param=param,var='ad')"

    ; Dust-to-gas ratio (sum over all bins)
    endif else if variables[iv] eq 'epsd' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(lnrho=lnrho,nd=nd,md=md,par=param,var='epsd')"

    ; Supersaturation level Pmon/Psat
    endif else if variables[iv] eq 'smon' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(lnrho=lnrho,ss=ss,nd=nd,md=md," + $
          "param=param,datadir=datadir,var='smon')"

    ; Dust mass unit
    endif else if variables[iv] eq 'unit_md' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(param=param,var='unit_md')"

    ; Average grain mass (mean over all bins)
    endif else if variables[iv] eq 'mdave' then begin
      tags[iv]=variables[iv]
      variables[iv]="pc_dust_aux(nd=nd,md=md,param=param,var='mdave')"
    endif

  endfor

end
