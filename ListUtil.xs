/* Copyright (c) 1997-2000 Graham Barr <gbarr@pobox.com>. All rights reserved.
 * This program is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 */
#define PERL_NO_GET_CONTEXT /* we want efficiency */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define NEED_sv_2pv_flags 1
#include "ppport.h"

#if PERL_BCDVERSION >= 0x5006000
#  include "multicall.h"
#endif

#ifndef CvISXSUB
#  define CvISXSUB(cv) CvXSUB(cv)
#endif

/* Some platforms have strict exports. And before 5.7.3 cxinc (or Perl_cxinc)
   was not exported. Therefore platforms like win32, VMS etc have problems
   so we redefine it here -- GMB
*/
#if PERL_BCDVERSION < 0x5007000
/* Not in 5.6.1. */
#  ifdef cxinc
#    undef cxinc
#  endif
#  define cxinc() my_cxinc(aTHX)
static I32
my_cxinc(pTHX)
{
    cxstack_max = cxstack_max * 3 / 2;
    Renew(cxstack, cxstack_max + 1, struct context); /* fencepost bug in older CXINC macros requires +1 here */
    return cxstack_ix + 1;
}
#endif

#ifndef sv_copypv
#define sv_copypv(a, b) my_sv_copypv(aTHX_ a, b)
static void
my_sv_copypv(pTHX_ SV *const dsv, SV *const ssv)
{
    STRLEN len;
    const char * const s = SvPV_const(ssv,len);
    sv_setpvn(dsv,s,len);
    if(SvUTF8(ssv))
        SvUTF8_on(dsv);
    else
        SvUTF8_off(dsv);
}
#endif

#ifdef SVf_IVisUV
#  define slu_sv_value(sv) (SvIOK(sv)) ? (SvIOK_UV(sv)) ? (NV)(SvUVX(sv)) : (NV)(SvIVX(sv)) : (SvNV(sv))
#else
#  define slu_sv_value(sv) (SvIOK(sv)) ? (NV)(SvIVX(sv)) : (SvNV(sv))
#endif

#if PERL_VERSION < 13 || (PERL_VERSION == 13 && PERL_SUBVERSION < 9)
#  define PERL_HAS_BAD_MULTICALL_REFCOUNT
#endif

#if PERL_VERSION < 14
#  define croak_no_modify() croak("%s", PL_no_modify)
#endif

enum slu_accum {
    ACC_IV,
    ACC_NV,
    ACC_SV,
};

static enum slu_accum accum_type(SV *sv) {
    if(SvAMAGIC(sv))
        return ACC_SV;

    if(SvIOK(sv) && !SvNOK(sv) && !SvUOK(sv))
        return ACC_IV;

    return ACC_NV;
}

/* Magic for set_subname */
static MGVTBL subname_vtbl;

MODULE=List::Util::XS       PACKAGE=List::Util::XS

void
min(...)
PROTOTYPE: @
ALIAS:
    min = 0
    max = 1
CODE:
{
    int index;
    NV retval;
    SV *retsv;
    int magic;

    if(!items)
        XSRETURN_UNDEF;

    retsv = ST(0);
    magic = SvAMAGIC(retsv);
    if(!magic)
      retval = slu_sv_value(retsv);

    for(index = 1 ; index < items ; index++) {
        SV *stacksv = ST(index);
        SV *tmpsv;
        if((magic || SvAMAGIC(stacksv)) && (tmpsv = amagic_call(retsv, stacksv, gt_amg, 0))) {
             if(SvTRUE(tmpsv) ? !ix : ix) {
                  retsv = stacksv;
                  magic = SvAMAGIC(retsv);
                  if(!magic) {
                      retval = slu_sv_value(retsv);
                  }
             }
        }
        else {
            NV val = slu_sv_value(stacksv);
            if(magic) {
                retval = slu_sv_value(retsv);
                magic = 0;
            }
            if(val < retval ? !ix : ix) {
                retsv = stacksv;
                retval = val;
            }
        }
    }
    ST(0) = retsv;
    XSRETURN(1);
}


void
sum(...)
PROTOTYPE: @
ALIAS:
    sum     = 0
    sum0    = 1
    product = 2
CODE:
{
    dXSTARG;
    SV *sv;
    IV retiv = 0;
    NV retnv = 0.0;
    SV *retsv = NULL;
    int index;
    enum slu_accum accum;
    int is_product = (ix == 2);
    SV *tmpsv;

    if(!items)
        switch(ix) {
            case 0: XSRETURN_UNDEF;
            case 1: ST(0) = newSViv(0); XSRETURN(1);
            case 2: ST(0) = newSViv(1); XSRETURN(1);
        }

    sv    = ST(0);
    switch((accum = accum_type(sv))) {
    case ACC_SV:
        retsv = TARG;
        sv_setsv(retsv, sv);
        break;
    case ACC_IV:
        retiv = SvIV(sv);
        break;
    case ACC_NV:
        retnv = slu_sv_value(sv);
        break;
    }

    for(index = 1 ; index < items ; index++) {
        sv = ST(index);
        if(accum < ACC_SV && SvAMAGIC(sv)){
            if(!retsv)
                retsv = TARG;
            sv_setnv(retsv, accum == ACC_NV ? retnv : retiv);
            accum = ACC_SV;
        }
        switch(accum) {
        case ACC_SV:
            tmpsv = amagic_call(retsv, sv,
                is_product ? mult_amg : add_amg,
                SvAMAGIC(retsv) ? AMGf_assign : 0);
            if(tmpsv) {
                switch((accum = accum_type(tmpsv))) {
                case ACC_SV:
                    retsv = tmpsv;
                    break;
                case ACC_IV:
                    retiv = SvIV(tmpsv);
                    break;
                case ACC_NV:
                    retnv = slu_sv_value(tmpsv);
                    break;
                }
            }
            else {
                /* fall back to default */
                accum = ACC_NV;
                is_product ? (retnv = SvNV(retsv) * SvNV(sv))
                           : (retnv = SvNV(retsv) + SvNV(sv));
            }
            break;
        case ACC_IV:
            if(is_product) {
                /* TODO: Consider if product() should shortcircuit the moment its
                 *   accumulator becomes zero
                 */
                if(retiv == 0 ||
                   (!SvNOK(sv) && SvIOK(sv) && (SvIV(sv) < IV_MAX / retiv))) {
                    retiv *= SvIV(sv);
                    break;
                }
                /* else fallthrough */
            }
            else {
                if(!SvNOK(sv) && SvIOK(sv) && (SvIV(sv) < IV_MAX - retiv)) {
                    retiv += SvIV(sv);
                    break;
                }
                /* else fallthrough */
            }

            /* fallthrough to NV now */
            retnv = retiv;
            accum = ACC_NV;
        case ACC_NV:
            is_product ? (retnv *= slu_sv_value(sv))
                       : (retnv += slu_sv_value(sv));
            break;
        }
    }

    if(!retsv)
        retsv = TARG;

    switch(accum) {
    case ACC_SV: /* nothing to do */
        break;
    case ACC_IV:
        sv_setiv(retsv, retiv);
        break;
    case ACC_NV:
        sv_setnv(retsv, retnv);
        break;
    }

    ST(0) = retsv;
    XSRETURN(1);
}

#define SLU_CMP_LARGER   1
#define SLU_CMP_SMALLER -1

void
minstr(...)
PROTOTYPE: @
ALIAS:
    minstr = SLU_CMP_LARGER
    maxstr = SLU_CMP_SMALLER
CODE:
{
    SV *left;
    int index;

    if(!items)
        XSRETURN_UNDEF;

    left = ST(0);
#ifdef OPpLOCALE
    if(MAXARG & OPpLOCALE) {
        for(index = 1 ; index < items ; index++) {
            SV *right = ST(index);
            if(sv_cmp_locale(left, right) == ix)
                left = right;
        }
    }
    else {
#endif
        for(index = 1 ; index < items ; index++) {
            SV *right = ST(index);
            if(sv_cmp(left, right) == ix)
                left = right;
        }
#ifdef OPpLOCALE
    }
#endif
    ST(0) = left;
    XSRETURN(1);
}




void
reduce(block,...)
    SV *block
PROTOTYPE: &@
CODE:
{
    SV *ret = sv_newmortal();
    int index;
    GV *agv,*bgv,*gv;
    HV *stash;
    SV **args = &PL_stack_base[ax];
    CV *cv    = sv_2cv(block, &stash, &gv, 0);

    if(cv == Nullcv)
        croak("Not a subroutine reference");

    if(items <= 1)
        XSRETURN_UNDEF;

    agv = gv_fetchpv("a", GV_ADD, SVt_PV);
    bgv = gv_fetchpv("b", GV_ADD, SVt_PV);
    SAVESPTR(GvSV(agv));
    SAVESPTR(GvSV(bgv));
    GvSV(agv) = ret;
    SvSetMagicSV(ret, args[1]);
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        dMULTICALL;
        I32 gimme = G_SCALAR;

        PUSH_MULTICALL(cv);
        for(index = 2 ; index < items ; index++) {
            GvSV(bgv) = args[index];
            MULTICALL;
            SvSetMagicSV(ret, *PL_stack_sp);
        }
#  ifdef PERL_HAS_BAD_MULTICALL_REFCOUNT
        if(CvDEPTH(multicall_cv) > 1)
            SvREFCNT_inc_simple_void_NN(multicall_cv);
#  endif
        POP_MULTICALL;
    }
    else
#endif
    {
        for(index = 2 ; index < items ; index++) {
            dSP;
            GvSV(bgv) = args[index];

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);

            SvSetMagicSV(ret, *PL_stack_sp);
        }
    }

    ST(0) = ret;
    XSRETURN(1);
}

void
first(block,...)
    SV *block
PROTOTYPE: &@
CODE:
{
    int index;
    GV *gv;
    HV *stash;
    SV **args = &PL_stack_base[ax];
    CV *cv    = sv_2cv(block, &stash, &gv, 0);

    if(cv == Nullcv)
        croak("Not a subroutine reference");

    if(items <= 1)
        XSRETURN_UNDEF;

    SAVESPTR(GvSV(PL_defgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        dMULTICALL;
        I32 gimme = G_SCALAR;
        PUSH_MULTICALL(cv);

        for(index = 1 ; index < items ; index++) {
            GvSV(PL_defgv) = args[index];
            MULTICALL;
            if(SvTRUEx(*PL_stack_sp)) {
#  ifdef PERL_HAS_BAD_MULTICALL_REFCOUNT
                if(CvDEPTH(multicall_cv) > 1)
                    SvREFCNT_inc_simple_void_NN(multicall_cv);
#  endif
                POP_MULTICALL;
                ST(0) = ST(index);
                XSRETURN(1);
            }
        }
#  ifdef PERL_HAS_BAD_MULTICALL_REFCOUNT
        if(CvDEPTH(multicall_cv) > 1)
            SvREFCNT_inc_simple_void_NN(multicall_cv);
#  endif
        POP_MULTICALL;
    }
    else
#endif
    {
        for(index = 1 ; index < items ; index++) {
            dSP;
            GvSV(PL_defgv) = args[index];

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);
            if(SvTRUEx(*PL_stack_sp)) {
                ST(0) = ST(index);
                XSRETURN(1);
            }
        }
    }
    XSRETURN_UNDEF;
}


void
any(block,...)
    SV *block
ALIAS:
    none   = 0
    all    = 1
    any    = 2
    notall = 3
PROTOTYPE: &@
PPCODE:
{
    int ret_true = !(ix & 2); /* return true at end of loop for none/all; false for any/notall */
    int invert   =  (ix & 1); /* invert block test for all/notall */
    GV *gv;
    HV *stash;
    SV **args = &PL_stack_base[ax];
    CV *cv    = sv_2cv(block, &stash, &gv, 0);

    if(cv == Nullcv)
        croak("Not a subroutine reference");

    SAVESPTR(GvSV(PL_defgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        dMULTICALL;
        I32 gimme = G_SCALAR;
        int index;

        PUSH_MULTICALL(cv);
        for(index = 1; index < items; index++) {
            GvSV(PL_defgv) = args[index];

            MULTICALL;
            if(SvTRUEx(*PL_stack_sp) ^ invert) {
                POP_MULTICALL;
                ST(0) = ret_true ? &PL_sv_no : &PL_sv_yes;
                XSRETURN(1);
            }
        }
        POP_MULTICALL;
    }
    else
#endif
    {
        int index;
        for(index = 1; index < items; index++) {
            dSP;
            GvSV(PL_defgv) = args[index];

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);
            if(SvTRUEx(*PL_stack_sp) ^ invert) {
                ST(0) = ret_true ? &PL_sv_no : &PL_sv_yes;
                XSRETURN(1);
            }
        }
    }

    ST(0) = ret_true ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

void
pairs(...)
PROTOTYPE: @
PPCODE:
{
    int argi = 0;
    int reti = 0;
    HV *pairstash = get_hv("List::Util::_Pair::", GV_ADD);

    if(items % 2 && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairs");

    {
        for(; argi < items; argi += 2) {
            SV *a = ST(argi);
            SV *b = argi < items-1 ? ST(argi+1) : &PL_sv_undef;

            AV *av = newAV();
            av_push(av, newSVsv(a));
            av_push(av, newSVsv(b));

            ST(reti) = sv_2mortal(newRV_noinc((SV *)av));
            sv_bless(ST(reti), pairstash);
            reti++;
        }
    }

    XSRETURN(reti);
}

void
unpairs(...)
PROTOTYPE: @
PPCODE:
{
    /* Unlike pairs(), we're going to trash the input values on the stack
     * almost as soon as we start generating output. So clone them first
     */
    int i;
    SV **args_copy;
    Newx(args_copy, items, SV *);
    SAVEFREEPV(args_copy);

    Copy(&ST(0), args_copy, items, SV *);

    for(i = 0; i < items; i++) {
        SV *pair = args_copy[i];
        AV *pairav;

        SvGETMAGIC(pair);

        if(SvTYPE(pair) != SVt_RV)
            croak("Not a reference at List::Util::unpack() argument %d", i);
        if(SvTYPE(SvRV(pair)) != SVt_PVAV)
            croak("Not an ARRAY reference at List::Util::unpack() argument %d", i);

        // TODO: assert pair is an ARRAY ref
        pairav = (AV *)SvRV(pair);

        EXTEND(SP, 2);

        if(AvFILL(pairav) >= 0)
            mPUSHs(newSVsv(AvARRAY(pairav)[0]));
        else
            PUSHs(&PL_sv_undef);

        if(AvFILL(pairav) >= 1)
            mPUSHs(newSVsv(AvARRAY(pairav)[1]));
        else
            PUSHs(&PL_sv_undef);
    }

    XSRETURN(items * 2);
}

void
pairkeys(...)
PROTOTYPE: @
PPCODE:
{
    int argi = 0;
    int reti = 0;

    if(items % 2 && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairkeys");

    {
        for(; argi < items; argi += 2) {
            SV *a = ST(argi);

            ST(reti++) = sv_2mortal(newSVsv(a));
        }
    }

    XSRETURN(reti);
}

void
pairvalues(...)
PROTOTYPE: @
PPCODE:
{
    int argi = 0;
    int reti = 0;

    if(items % 2 && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairvalues");

    {
        for(; argi < items; argi += 2) {
            SV *b = argi < items-1 ? ST(argi+1) : &PL_sv_undef;

            ST(reti++) = sv_2mortal(newSVsv(b));
        }
    }

    XSRETURN(reti);
}

void
pairfirst(block,...)
    SV *block
PROTOTYPE: &@
PPCODE:
{
    GV *agv,*bgv,*gv;
    HV *stash;
    CV *cv    = sv_2cv(block, &stash, &gv, 0);
    I32 ret_gimme = GIMME_V;
    int argi = 1; /* "shift" the block */

    if(!(items % 2) && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairfirst");

    agv = gv_fetchpv("a", GV_ADD, SVt_PV);
    bgv = gv_fetchpv("b", GV_ADD, SVt_PV);
    SAVESPTR(GvSV(agv));
    SAVESPTR(GvSV(bgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        /* Since MULTICALL is about to move it */
        SV **stack = PL_stack_base + ax;

        dMULTICALL;
        I32 gimme = G_SCALAR;

        PUSH_MULTICALL(cv);
        for(; argi < items; argi += 2) {
            SV *a = GvSV(agv) = stack[argi];
            SV *b = GvSV(bgv) = argi < items-1 ? stack[argi+1] : &PL_sv_undef;

            MULTICALL;

            if(!SvTRUEx(*PL_stack_sp))
                continue;

            POP_MULTICALL;
            if(ret_gimme == G_ARRAY) {
                ST(0) = sv_mortalcopy(a);
                ST(1) = sv_mortalcopy(b);
                XSRETURN(2);
            }
            else
                XSRETURN_YES;
        }
        POP_MULTICALL;
        XSRETURN(0);
    }
    else
#endif
    {
        for(; argi < items; argi += 2) {
            dSP;
            SV *a = GvSV(agv) = ST(argi);
            SV *b = GvSV(bgv) = argi < items-1 ? ST(argi+1) : &PL_sv_undef;

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);

            SPAGAIN;

            if(!SvTRUEx(*PL_stack_sp))
                continue;

            if(ret_gimme == G_ARRAY) {
                ST(0) = sv_mortalcopy(a);
                ST(1) = sv_mortalcopy(b);
                XSRETURN(2);
            }
            else
                XSRETURN_YES;
        }
    }

    XSRETURN(0);
}

void
pairgrep(block,...)
    SV *block
PROTOTYPE: &@
PPCODE:
{
    GV *agv,*bgv,*gv;
    HV *stash;
    CV *cv    = sv_2cv(block, &stash, &gv, 0);
    I32 ret_gimme = GIMME_V;

    /* This function never returns more than it consumed in arguments. So we
     * can build the results "live", behind the arguments
     */
    int argi = 1; /* "shift" the block */
    int reti = 0;

    if(!(items % 2) && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairgrep");

    agv = gv_fetchpv("a", GV_ADD, SVt_PV);
    bgv = gv_fetchpv("b", GV_ADD, SVt_PV);
    SAVESPTR(GvSV(agv));
    SAVESPTR(GvSV(bgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        /* Since MULTICALL is about to move it */
        SV **stack = PL_stack_base + ax;
        int i;

        dMULTICALL;
        I32 gimme = G_SCALAR;

        PUSH_MULTICALL(cv);
        for(; argi < items; argi += 2) {
            SV *a = GvSV(agv) = stack[argi];
            SV *b = GvSV(bgv) = argi < items-1 ? stack[argi+1] : &PL_sv_undef;

            MULTICALL;

            if(SvTRUEx(*PL_stack_sp)) {
                if(ret_gimme == G_ARRAY) {
                    /* We can't mortalise yet or they'd be mortal too early */
                    stack[reti++] = newSVsv(a);
                    stack[reti++] = newSVsv(b);
                }
                else if(ret_gimme == G_SCALAR)
                    reti++;
            }
        }
        POP_MULTICALL;

        if(ret_gimme == G_ARRAY)
            for(i = 0; i < reti; i++)
                sv_2mortal(stack[i]);
    }
    else
#endif
    {
        for(; argi < items; argi += 2) {
            dSP;
            SV *a = GvSV(agv) = ST(argi);
            SV *b = GvSV(bgv) = argi < items-1 ? ST(argi+1) : &PL_sv_undef;

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);

            SPAGAIN;

            if(SvTRUEx(*PL_stack_sp)) {
                if(ret_gimme == G_ARRAY) {
                    ST(reti++) = sv_mortalcopy(a);
                    ST(reti++) = sv_mortalcopy(b);
                }
                else if(ret_gimme == G_SCALAR)
                    reti++;
            }
        }
    }

    if(ret_gimme == G_ARRAY)
        XSRETURN(reti);
    else if(ret_gimme == G_SCALAR) {
        ST(0) = newSViv(reti);
        XSRETURN(1);
    }
}

void
pairmap(block,...)
    SV *block
PROTOTYPE: &@
PPCODE:
{
    GV *agv,*bgv,*gv;
    HV *stash;
    CV *cv    = sv_2cv(block, &stash, &gv, 0);
    SV **args_copy = NULL;
    I32 ret_gimme = GIMME_V;

    int argi = 1; /* "shift" the block */
    int reti = 0;

    if(!(items % 2) && ckWARN(WARN_MISC))
        warn("Odd number of elements in pairmap");

    agv = gv_fetchpv("a", GV_ADD, SVt_PV);
    bgv = gv_fetchpv("b", GV_ADD, SVt_PV);
    SAVESPTR(GvSV(agv));
    SAVESPTR(GvSV(bgv));
/* This MULTICALL-based code appears to fail on perl 5.10.0 and 5.8.9
 * Skip it on those versions (RT#87857)
 */
#if defined(dMULTICALL) && (PERL_BCDVERSION > 0x5010000 || PERL_BCDVERSION < 0x5008009)
    if(!CvISXSUB(cv)) {
        /* Since MULTICALL is about to move it */
        SV **stack = PL_stack_base + ax;
        I32 ret_gimme = GIMME_V;
        int i;

        dMULTICALL;
        I32 gimme = G_ARRAY;

        PUSH_MULTICALL(cv);
        for(; argi < items; argi += 2) {
            SV *a = GvSV(agv) = args_copy ? args_copy[argi] : stack[argi];
            SV *b = GvSV(bgv) = argi < items-1 ? 
                (args_copy ? args_copy[argi+1] : stack[argi+1]) :
                &PL_sv_undef;
            int count;

            MULTICALL;
            count = PL_stack_sp - PL_stack_base;

            if(count > 2 && !args_copy) {
                /* We can't return more than 2 results for a given input pair
                 * without trashing the remaining argmuents on the stack still
                 * to be processed. So, we'll copy them out to a temporary
                 * buffer and work from there instead.
                 * We didn't do this initially because in the common case, most
                 * code blocks will return only 1 or 2 items so it won't be
                 * necessary
                 */
                int n_args = items - argi;
                Newx(args_copy, n_args, SV *);
                SAVEFREEPV(args_copy);

                Copy(stack + argi, args_copy, n_args, SV *);

                argi = 0;
                items = n_args;
            }

            for(i = 0; i < count; i++)
                stack[reti++] = newSVsv(PL_stack_sp[i - count + 1]);
        }
        POP_MULTICALL;

        if(ret_gimme == G_ARRAY)
            for(i = 0; i < reti; i++)
                sv_2mortal(stack[i]);
    }
    else
#endif
    {
        for(; argi < items; argi += 2) {
            dSP;
            SV *a = GvSV(agv) = args_copy ? args_copy[argi] : ST(argi);
            SV *b = GvSV(bgv) = argi < items-1 ? 
                (args_copy ? args_copy[argi+1] : ST(argi+1)) :
                &PL_sv_undef;
            int count;
            int i;

            PUSHMARK(SP);
            count = call_sv((SV*)cv, G_ARRAY);

            SPAGAIN;

            if(count > 2 && !args_copy && ret_gimme == G_ARRAY) {
                int n_args = items - argi;
                Newx(args_copy, n_args, SV *);
                SAVEFREEPV(args_copy);

                Copy(&ST(argi), args_copy, n_args, SV *);

                argi = 0;
                items = n_args;
            }

            if(ret_gimme == G_ARRAY)
                for(i = 0; i < count; i++)
                    ST(reti++) = sv_mortalcopy(SP[i - count + 1]);
            else
                reti += count;

            PUTBACK;
        }
    }

    if(ret_gimme == G_ARRAY)
        XSRETURN(reti);

    ST(0) = sv_2mortal(newSViv(reti));
    XSRETURN(1);
}

void
shuffle(...)
PROTOTYPE: @
CODE:
{
    int index;
#if (PERL_VERSION < 9)
    struct op dmy_op;
    struct op *old_op = PL_op;

    /* We call pp_rand here so that Drand01 get initialized if rand()
       or srand() has not already been called
    */
    memzero((char*)(&dmy_op), sizeof(struct op));
    /* we let pp_rand() borrow the TARG allocated for this XS sub */
    dmy_op.op_targ = PL_op->op_targ;
    PL_op = &dmy_op;
    (void)*(PL_ppaddr[OP_RAND])(aTHX);
    PL_op = old_op;
#else
    /* Initialize Drand01 if rand() or srand() has
       not already been called
    */
    if(!PL_srand_called) {
        (void)seedDrand01((Rand_seed_t)Perl_seed(aTHX));
        PL_srand_called = TRUE;
    }
#endif

    for (index = items ; index > 1 ; ) {
        int swap = (int)(Drand01() * (double)(index--));
        SV *tmp = ST(swap);
        ST(swap) = ST(index);
        ST(index) = tmp;
    }

    XSRETURN(items);
}


BOOT:
{
    HV *lu_stash = gv_stashpvn("List::Util", 10, TRUE);
    GV *rmcgv = *(GV**)hv_fetch(lu_stash, "REAL_MULTICALL", 14, TRUE);
    SV *rmcsv;
    if(SvTYPE(rmcgv) != SVt_PVGV)
        gv_init(rmcgv, lu_stash, "List::Util", 10, TRUE);
    rmcsv = GvSVn(rmcgv);
#ifdef REAL_MULTICALL
    sv_setsv(rmcsv, &PL_sv_yes);
#else
    sv_setsv(rmcsv, &PL_sv_no);
#endif
}
