use ExtUtils::MakeMaker;

## Borrowed this Makefile.PL template from Damion Wilson's DKW
## distribution.

sub MY::postamble
   {
    return unless $ExtUtils::MakeMaker::Is_Win32;

    "trigger ::\n".
    "\t".'$(CHMOD) 777 $(INST_LIBDIR)\/Tk'."\n".
    "\t".'@$(MKPATH) $(INST_LIBDIR)\/Tk'."\n".
    "\t".'$(PERL) -MExtUtils::Command -e cp $(TO_INST_PM) $(INST_LIBDIR)\/Tk'."\n".
    "\t".'$(PERL) -MExtUtils::Command -e cp $(TO_INST_PM) blib/lib/Tk'."\n".
    "\n";
   }

WriteMakefile
   (
    PREREQ_PM =>
       {
        'Tk' => '800.005',
       },

    PMLIBDIRS => ['Tk'],
    DISTNAME => 'Tk-TextList',
    VERSION_FROM => 'TextList.pm',
    NAME => 'Tk::TextList',

    'dist' =>
       {
        COMPRESS => 'gzip -9f',
        SUFFIX => '.gz', 
       },

    ! $ExtUtils::MakeMaker::Is_Win32 ? () :
       (
        'depend' =>
           {
            'all:' => 'trigger',
           }
       ),
   );
