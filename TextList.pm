## Copyright (c) 1999 Greg London. All rights reserved.
## Copyright (c) 2000 Rob Seegel

## This program is free software; you can redistribute it and/or
## modify it under the same terms as Perl itself.

## code for bindings based on the code from Listbox.pm
## comments specifying method functionality taken from
## "Perl/Tk Pocket Reference" by Stephen Lidie.

## Many comments in here indicate something akin to
## "compensate for one-based index" These aren't meant
## to describe what is going on, but why. This way
## I can quickly track down all the places where it
## takes place. 

package Tk::TextList;

use strict;
use Carp;
use vars qw($VERSION);
$VERSION = '3.53'; # $Id: //depot/Tk8/TextList/TextList.pm#2 $

use Tk qw (Ev);
use base qw(Tk::Derived Tk::ROText);

Construct Tk::Widget 'TextList';
                    
sub ClassInit {
  my ($class,$mw) = @_;

  $mw->bind($class, "all", "");

  ## Standard Motif bindings:
  $mw->bind($class,'<1>', ['BeginSelect', Ev('@')]);

  $mw->bind($class,'<B1-Motion>', ['Motion', Ev('@')]);
  $mw->bind($class,'<ButtonRelease-1>','ButtonRelease_1');

  $mw->bind($class,'<Shift-1>', ['BeginExtend', Ev('@')]);
  $mw->bind($class,'<Control-1>', ['BeginToggle', Ev('@')]);

  $mw->bind($class,'<B1-Leave>', 'AutoScan');
  $mw->bind($class,'<B1-Enter>','CancelRepeat');
  $mw->bind($class,'<Up>',['UpDown',-1]);
  $mw->bind($class,'<Shift-Up>',['ExtendUpDown',-1]);
  $mw->bind($class,'<Down>',['UpDown',1]);
  $mw->bind($class,'<Shift-Down>',['ExtendUpDown',1]);

  $mw->XscrollBind($class);
  $mw->PriorNextBind($class);

  $mw->bind($class,'<Control-Home>','Cntrl_Home');

  $mw->bind($class,'<Shift-Control-Home>',['DataExtend',0]);
  $mw->bind($class,'<Control-End>','Cntrl_End');

  $mw->bind($class,'<Shift-Control-End>',['DataExtend','end']);
  $class->clipboardOperations($mw,'Copy');
  $mw->bind($class,'<space>',['BeginSelect', 'active']);
  $mw->bind($class,'<Select>',['BeginSelect', 'active']);
  $mw->bind($class,'<Control-Shift-space>',['BeginExtend', 'active']);
  $mw->bind($class,'<Shift-Select>',['BeginExtend', 'active']);
  $mw->bind($class,'<Escape>','Cancel');
  $mw->bind($class,'<Control-slash>','SelectAll');
  $mw->bind($class,'<Control-backslash>','Cntrl_backslash');

  # Additional Tk bindings that aren't part of the Motif look and feel:
  $mw->bind($class,'<2>',['scan','mark',Ev('x'),Ev('y')]);
  $mw->bind($class,'<B2-Motion>',['scan','dragto',Ev('x'),Ev('y')]);

  $mw->bind($class,'<FocusIn>' , 'FocusIn');
  $mw->bind($class,'<FocusOut>', 'FocusOut');

  return $class;
}




sub Populate {
  my ($w, $args) = @_;

  my $selectMode = delete $args->{-selectmode} || 'browse';
  my $font       = delete $args->{-font};

  ## Ensure correct default font on MS platform
  if (!$font) {
    if ($Tk::platform eq 'MSWin32') {
      $font = "{MS Sans Serif} 8";
    }
  }
  my $defWidth   = 20;
  my $defHeight  = 10;

  $w->{_lastSubmittedW} = $args->{-width};
  $w->{_lastSubmittedH} = $args->{-height};

  $w->SUPER::Populate($args);

  $w->ConfigSpecs(
    -selectmode => [qw/PASSIVE   selectMode SelectMode/,$selectMode],
    -font       => [qw/SELF      font       Font/,      $font      ],
    -justify    => [qw/METHOD    justify    Justify/,   undef      ],
    -spacing3   => [qw/SELF      spacing3   Spacing3    2/         ],   
    -cursor     => [qw/SELF      cursor     Cursor      left_ptr/  ],
    -state      => [qw/SELF      state      State       disabled/  ],
    -wrap       => [qw/SELF      wrap       Wrap        none/      ],
    -width      => [qw/SELF      width      Width/,     $defWidth  ],
    -height     => [qw/SELF      height     Height/,    $defHeight ],
    -selectborderwidth => ['SELF', undef,   undef,      1          ]
  ); 

  ## Create a few 'private' vars to keep state on dynamic sizing
  ## Dynamic sizing defaults to being off, but it is enabled if
  ## fields are set to below 1 
  $w->{_dynWidth}  = 0;
  $w->{_dynHeight} = 0;

  ## if the last submitted height or width is not defined,
  ## it might be because they were not submitted, or that
  ## this widget was created using 'Scrolled'. In these 
  ## cases, take the defaults temporarily. If it turns out
  ## that these values were set by Scrolled method then
  ## it will be adjusted whenever an insert is called. If
  ## submitted values are defined and less than zero, enable
  ## dynamic sizing
  if (!defined($w->{_lastSubmittedW})) { 
    $w->{_lastSubmittedW} = $defWidth;

  } else {
    if ($w->{_lastSubmittedW} < 1) {
      $w->{_dynWidth} = 1;
    }
  }   

  if (!defined($w->{_lastSubmittedH})) {
    $w->{_lastSubmittedH} = $defHeight;

  } else {
    if ($w->{_lastSubmittedH} < 1) {
      $w->{_dynHeight} = 1;
    }
  }  
}

## activate( <element> )
## set the active element to index
## "active" is a text "mark" which underlines the marked text.
sub activate {
  my ($w, $element) = @_;

  $element = $w->index($element) . '.0';
  $w->SUPER::tagRemove('_ACTIVE_TAG', '1.0','end');
  $w->SUPER::tagAdd('_ACTIVE_TAG',
    $element . ' linestart', $element.' lineend');
  $w->SUPER::markSet('active', $element);
}

## bbox( <index> ) => (x, y, width, height)
## returns a list (x,y,width,height) giving an approximate
## bounding box surrounding the characters at a given index
sub bbox {
  my ($w, $element) = @_;
  $element = $w->index($element). '.0';
  my @info = $w->SUPER::dlineinfo($element);
  pop @info;
  return @info;
}

## curselection() => (selected indices)
## returns a list of indices of all elements currently selected
sub curselection {
  my $w = shift;
  my @ranges = $w->SUPER::tagRanges('sel');
  my @selection_list;
  while (@ranges) {
    my ($first,$firstcol) = split(/\./,shift(@ranges));
    my ($last,$lastcol) = split(/\./,shift(@ranges));

    ## if previous selection ended on the same line that this selection 
    ## starts, then fiddle the numbers so that this line number is not 
    ## included twice.
    if (defined($selection_list[-1]) and 
       ($first == $selection_list[-1]))
    {
      ## Count this selection starting from the next line
      $first++; 
    }

    if ($lastcol == 0) {
      $last -= 1;
    }

    ## if incrementing $first causes it to be greater than $last,
    ## then do nothing, else add (first .. last) to list
    unless ($first > $last) {
      push(@selection_list, $first .. $last);
    }
  }
  # Adjust to present a zero-based index
  foreach (@selection_list) { $_--; }
  return @selection_list;
}

## delete( <element> [,<element2>] )
## deletes one element or a range of elements from the listbox
sub delete {
  my ($w, $element1, $element2) = @_;
  my ($index1, $index2);

  $element2 = $element1 unless(defined($element2));
  $index1 = $w->index($element1);
  $index2 = $w->index($element2);

  ## Allow ranges to be expressed backwards
  if ($index2 < $index1) {
    ($index1, $index2) = ($index2, $index1);
  }
  $w->configure(-state => 'normal');
  $w->SUPER::delete($index1.'.0' , $index2.'.0 lineend + 1 chars'); 
  $w->configure(-state => 'disabled');

  ## Check if dynamic Height/Width sizing is enabled
  ## and adjust height/width as appropriate
  $w->_checkHeight;
  $w->_checkWidth;
}

## get( <element> [,<element2>]
## returns one element or a range of list elements from the listbox
sub get {
  my ($w, $element1, $element2) = @_;
  my ($index1, $index2);
  my @getList;

  $element2 = $element1 unless(defined($element2));
  $index1 = $w->index($element1);
  $index2 = $w->index($element2);

  ## Allow ranges to be expressed backwards
  if ($index2 < $index1) {
    ($index1, $index2) = ($index2, $index1);
  }
  
  for ( my $i = $index1; $i <= $index2; $i++) {
    push @getList, $w->SUPER::get($i.'.0 linestart', $i.'.0 lineend');
  }
  return @getList;
}

## index(<element>)
## returns index in number notation
## Possibly the most used (and abused) method in this class, index
## is used by many other methods to give the appearance of the zero-
## based index which Listbox has.
sub index {
  my ($w, $element) = @_;
  return undef unless(defined($element));
 
  $element++       unless $element=~/\D/;
  $element .= '.0' unless $element=~/\D/;
  $element = $w->SUPER::index($element);
  my ($line, $col) = split(/\./, $element);
  return $line; 
}

## insert(<index>, (<element>))
## inserts specified elements before the submitted index
sub insert {
  my $w = shift;
  my $element = shift;
  my $index  = $w->index($element);

  ## Remove carriage returns
  $element =~ s/\n//;

  ## I want this widget to work like Listbox, and that means
  ## that it must work when it is called from Scrolled, 
  ## unfortunately when it is called from Scrolled, the 
  ## configurations which are passed don't all seem to take
  ## Since an insert is required before this widget can really
  ## be considered useful, I recall all the current 
  ## configurations and force the widget to reconfigure itself
  ## I hate that I have to do this, and hope to find another
  ## way.
  foreach (keys %{$w->{Configure}}) {
    $w->configure($_ => $w->{Configure}{$_});
  }

  $w->configure(-state => 'normal');
  ## If TextList has any elements there is a question
  ## of whether or not a carriage return needs to be
  ## added. If you are adding to the end of a list,
  ## a carriage return must be added FIRST
  if ($w->size > 0) {
    if ($w->index("end") == $index) {
      $w->SUPER::insert("end - 1 chars", "\n");
    }
  }

  ## In the case of a list of elements being added
  ## temporarily remove the last element, add each
  ## element with carriage returns, then add the
  ## the last element without a carriage return
  ## to eliminate the extra 'phantom' element
  my $lastItem = pop(@_);
  my $item;
  while (@_) {
    $item = shift(@_);
    $item .= "\n";
    $w->SUPER::insert($index++. '.0', $item, '__style');
  }
  $w->SUPER::insert($index++.'.0', $lastItem, '__style');
  $w->configure(-state => 'disabled');

  ## Checks height and width after the insert(s),
  ## if dynamic sizing is enabled then widget size
  ## will be readjusted automatically
  $w->_checkWidth;
  $w->_checkHeight;
}

## justify(<option>)
## justifies each element to either ('left', 'right', or 'center')
sub justify {
  my $w = shift;
  my $option = shift;
  $w->tagConfigure('__style', -justify => $option);
}

## nearest( <y coord value> ) => N
## I'm not precisely sure this will work. It is meant to find the
## index which is closest to the Y Coordinate. 
sub nearest {
  my ($w, $yCoord) = @_;
  return undef unless (defined($yCoord));
  return $w->index('@0,' . $yCoord);
}

## see(<element>)
## adjusts the view in window so element at index is completely visible
sub see {
  my ($w, $element) = @_;
  $element = $w->index($element);
  $w->SUPER::see($element.'.0');
}

## selected( <option>, <arg1> [, <argn>])
## dispatches methods off using submethod
sub selected {
  my $w = shift;
  my $command = shift;

  if ( $command =~ /get/i )   { $w->selectedSet(@_); return; }
  if ( $command =~ /delete/i) { $w->selectedDelete(@_); return }
  carp "Unsupported selected command: $command\n";
}

## selectedSet( <tag name>, <element1> [, <element2> ])
## remove a tag based on element numbers
sub selectedDelete {
  my $w = shift;
  foreach my $i (reverse $w->curselection) {
    $w->delete($i);
  }
}

## selectedGet( <tag name>, <element1> [, <element2> ])
## remove a tag based on element numbers
sub selectedGet {
  my $w = shift;
  my @result = ();

  foreach my $i ($w->curselection) {
    push(@result, $w->get($i));
  }
  return (wantarray) ? @result : $result[0];
}

## selection( <option> )
## Delegates the method to a submethod
sub selection {
  my $w = shift;
  my $command = shift;

  if ($command =~ /anchor/i)   { $w->selectionAnchor(@_); return; }
  if ($command =~ /clear/i)    { $w->selectionClear(@_); return; }
  if ($command =~ /includes/i) { $w->selectionIncludes(@_); return; }
  if ($command =~ /set/i)      { $w->selectionSet(@_); return; }
  carp "Unsupported selection command: $command";
}

## selectionAnchor( <element> )
## Sets the selection anchor to element at index
sub selectionAnchor {
  my ($w, $element) = @_;
  $element = $w->index($element);
  $w->SUPER::markSet('anchor', $element.'.0');
}

## selectionClear
##  deselects elements between index1 and index2, inclusive
sub selectionClear {
  my ($w, $element1, $element2) = @_;
  my ($index1, $index2);

  $element2 = $element1 unless(defined($element2));
  $index1 = $w->index($element1);
  $index2 = $w->index($element2);

  if ($index2 < $index1) {
    ($index1, $index2) = ($index2, $index1);
  }
  $w->SUPER::tagRemove('sel', $index1.'.0', $index2.'.0 lineend +1c');
}


## returns 1 if element at index is selected, 0 otherwise.
sub selectionIncludes {
  my ($w, $element) = @_;

  ## Note that this method requires that $element be reduced
  ## by one negating the affects of the offset that index
  ## produces. This is necessary because curselection shows
  ## selected zero-based indexes and NOT 1-based. index is only
  ## used to translate non-numeric elements
  $element = $w->index($element);
  $element--;
  my @list = $w->curselection;
  my $line;
  foreach $line (@list) {
    if ($line == $element) {return 1;}
  }
  return 0;
}

## selectionSet(<element1> [,<element2>])
## adds all elements between element1 and element2 inclusive to selection
sub selectionSet {
  my ($w, $element1, $element2) = @_;
  my ($index1, $index2);

  $element2 = $element1 unless(defined($element2));
  $index1 = $w->index($element1);
  $index2 = $w->index($element2);

  ## Allow inverted selectionSet (upward selection)
  if ($index2 < $index1) {
    ($index1, $index2) = ($index2, $index1);
  }
  $w->SUPER::tagAdd('sel', $index1.'.0', $index2.'.0 lineend +1c');
  $w->SUPER::tagRaise('sel');
}

## setList( <element_array> )
## an alternate way of filling with list elements 
sub setList {
 my $w = shift;
 $w->delete(0,'end');
 $w->insert('end',@_);
}

## size() 
## returns number of elements in listbox
sub size {
  my $w = shift;

  ## Yank out the contents of the text widget
  ## split the content into lines and then
  ## return that line count.
  my $contents = $w->SUPER::get("1.0", "end");
  return scalar( my @lines =  split(/\n/, $contents) );
}

## tag(<command>, <args>, ...)
## pass tag command to sub method

sub tag {
  my $w = shift;
  my $cmd = shift;

  if ($cmd =~ /add$/i)      { $w->tagAdd(@_); return; }
  if ($cmd =~ /addChar/i)   { $w->tagAddChar(@_); return; }
  if ($cmd =~ /remove$/i)   { $w->tagRemove(@_); return; }
  if ($cmd =~ /removeChar/) { $w->tagRemoveChar(@_); return; }
  carp "Unsupported command for tag: $cmd";
}

## tagAdd(<tag name>, <element1> [,<element2])
## add a tag based on element numbers
sub tagAdd {
  my ($w, $tagName, $element1, $element2)=@_;

  $element1 = $w->index($element1);
  $element1 .= '.0';

  $element2 = $element1 . ' lineend' unless(defined($element2));
  $element2 = $w->index($element2);
  $element2.='.0 lineend +1c';

  $w->SUPER::tagAdd($tagName, $element1, $element2);
}

## add a tag based on line.char indexes
sub tagAddChar {
 my ($w, $tagName, $element, $charIndex1, $charIndex2) = @_;

 
 $element = $w->index($element);
 $charIndex2 = $charIndex1 + 1 unless (defined($charIndex2));

 $charIndex1 = $element . "." . $charIndex1;
 $charIndex2 = $element . "." . $charIndex2;

 if ($charIndex2 < $charIndex1) {
   ($charIndex1, $charIndex2) = ($charIndex2, $charIndex1);
 }

 $w->SUPER::tagAdd($tagName, $charIndex1, $charIndex2);
}

## tagRemove( <tag name>, <element1> [, <element2> ])
## remove a tag based on element numbers
sub tagRemove {
  my ($w, $tagName, $element1, $element2)=@_;
  $element1 = $w->index($element1);
  $element1 .= '.0';

  $element2 = $element1.' lineend' unless(defined($element2));
  $element2 = $w->index($element2);
  $element2.='.0 lineend +1c';

  $w->SUPER::tagRemove($tagName, $element1, $element2);
}

## remove a tag based on line.char indexes
sub tagRemoveChar {
 my ($w, $tagName, $element, $charIndex1, $charIndex2) = @_;
 
 $element = $w->index($element);
 $charIndex2 = $charIndex1 + 1 unless (defined($charIndex2));

 if ($charIndex2 < $charIndex1) {
   ($charIndex1, $charIndex2) = ($charIndex2, $charIndex1);
 }
 $charIndex1 = $element . "." . $charIndex1;
 $charIndex2 = $element . "." . $charIndex2;

 $w->SUPER::tagRemove($tagName, $charIndex1, $charIndex2);
}

##                       PRIVATE METHODS                             ##
## _checkWidth
## procedure checks to see whether or not sizing is dynamic, then
## if sizing IS dynamic, widget reconfigures itself to the width of
## of the widest element
sub _checkWidth {
  my $w = shift;
  my $currentWidth = $w->{Configure}{-width};

  ## If the currently configured width is different
  ## from the last submitted width, it means that
  ## the user has submitted a new value
  if ($currentWidth != $w->{_lastSubmittedW}) {
    if    ($currentWidth < 1) {  $w->{_dynWidth} = 1; }
    else                      {  $w->{_dynWidth} = 0; }
  }

  ## If dynamic sizing is enabled go ahead and find
  ## an appropriate width from current list elements
  if ($w->{_dynWidth} == 1) {
    my @existingEl = $w->get(0, 'end');
    $currentWidth = 0;

    my $len;
    foreach (@existingEl) {
      $len = length($_);
      if ($len > $currentWidth) {
	$currentWidth = $len;
      }
    }
    ## Don't mess with reconfiguring if the width
    ## has not changed
    if ($currentWidth != $w->{_lastSubmittedW}) {
      $w->{_lastSubmittedW} = $currentWidth;
      $w->configure(-width => $currentWidth);
    }
  }
}

## _checkHeight
## procedure checks to determine whether or not Height sizing is
## dynamic or static, if it dynamic then widgets is reconfigured
## as appropriate to fit exactly the number of elements inside
## the TextList 
sub _checkHeight {
  my $w = shift;
  my $currentHeight = $w->{Configure}{-height};

  ## If the currently configured width is different
  ## from the last submitted width, it means that
  ## the user has submitted a new value
  if ($currentHeight != $w->{_lastSubmittedH}) {
    if    ($currentHeight < 1) {  $w->{_dynHeight} = 1; }
    else                       {  $w->{_dynHeight} = 0; }
  }

  ## If dynamic sizing is enabled go ahead and find
  ## an appropriate Height from number of current
  ## list elements

  if ($w->{_dynHeight} == 1) {
     $currentHeight = $w->size;
     $w->{_lastSubmittedH} = $currentHeight;
     $w->configure(-height => $currentHeight);
  }
} 


##                   EVENT HANDLER ROUTINES                          ##

## AutoScan (xCoord, yCoord)
## This procedure is invoked when the mouse leaves an entry window
## with button 1 down. It scrolls the window up, down, left, or
## right, depending on where the mouse left the window, and reschedules
## itself as an "after" command so that the window continues to scroll
## until the mouse moves back into the window or the mouse button is
## released.
##
## Arguments:
## w - The entry window.
sub AutoScan {
  my $w  = shift;

  my $Ev = $w->XEvent;
  my $xCoord = $Ev->x;
  my $yCoord = $Ev->y;
 
  if ($yCoord >= $w->height) {
    $w->yview('scroll',1,'units')

  } elsif ($yCoord < 0) {
    $w->yview('scroll',-1,'units')

  } elsif ($xCoord >= $w->width) {
    $w->xview('scroll',2,'units')

  } elsif ($xCoord < 0) {
    $w->xview('scroll',-2,'units')

  } else {
    return;
  }
  $w->Motion($w->index("@" . $xCoord . ',' . $yCoord));
  $w->RepeatId($w->after(50,'AutoScan', $w));
}

## BeginExtend( <element> )
##
## This procedure is typically invoked on shift-button-1 presses. It
## begins the process of extending a selection in the listbox. Its
## exact behavior depends on the selection mode currently in effect
## for the listbox; see the Motif documentation for details.
##
## Arguments:
## w - The listbox widget.
## element - The element for the selection operation (typically the
## one under the pointer). Must be in numerical form.
sub BeginExtend {
  my $w  = shift;
  my $el = shift;

  ## if no selections, select current
  if ($w->curselection == 0 ) {
    $w->BeginSelect($el);
    return;
  }
  if ($w->cget('-selectmode') eq 'extended' && 
      $w->selectionIncludes('anchor'))
  {
    $w->Motion($el);
  }
}

sub ButtonRelease_1 {
  my $w = shift;
  my $Ev = $w->XEvent;
  $w->CancelRepeat;
  $w->activate($Ev->xy);
}

## BeginSelect( <element> )
##
## This procedure is typically invoked on button-1 presses. It begins
## the process of making a selection in the listbox. Its exact behavior
## depends on the selection mode currently in effect for the listbox;
## see the Motif documentation for details.
##
## Arguments:
## w - The listbox widget.
## el - The element for the selection operation (typically the
## one under the pointer). Must be in numerical form.
sub BeginSelect {
  my ($w, $el) = @_;

  ## All selection modes start out the same way
  ## except for multiple. Might as well put the
  ## the most likely condition first.

  if ($w->cget('-selectmode') ne 'multiple') {
    $w->selectionClear(0,'end');
    $w->selectionSet($el);
    $w->selectionAnchor($el);
    my @list = ();
    $w->{_selectionListRef} = \@list;
    $w->{_prevElement} = $w->index($el);
   
  } else {

    if ($w->selectionIncludes($el)) {
      $w->selectionClear($el)
    } else {
      $w->selectionSet($el)
    }
  }
  $w->focus;
}

## BeginToggle(<element>)
##
## This procedure is typically invoked on control-button-1 presses. It
## begins the process of toggling a selection in the listbox. Its
## exact behavior depends on the selection mode currently in effect
## for the listbox; see the Motif documentation for details.
##
## Arguments:
## w - The listbox widget.
## el - The element for the selection operation (typically the
## one under the pointer). Must be in numerical form.
sub BeginToggle {
  my $w = shift;
  my $element = shift;

  if ($w->cget('-selectmode') eq 'extended') {
    my @list = $w->curselection();
    $w->{_selectionListRef} = \@list;
    $w->{_prevElement} = $w->index($element);
    $w->selectionAnchor($element);
    if ($w->selectionIncludes($element)) {
      $w->selectionClear($element)

    } else {
      $w->selectionSet($element)
    }
  }
}

## Cancel
##
## This procedure is invoked to cancel an extended selection in
## progress. If there is an extended selection in progress, it
## restores all of the items between the active one and the anchor
## to their previous selection state.
##
## Arguments:
## w - The listbox widget.
sub Cancel {
  my $w = shift;
  if ($w->cget('-selectmode') ne 'extended' ||
      !defined $w->{_prevElement})
  {
    return;
  }
  my $first = $w->index('anchor');
  my $last = $w->{_prevElement};
  if ($first > $last) {
    ($first, $last)=($last, $first);
  }
  $w->selectionClear($first, $last);
  while ($first <= $last) { 
    if (Tk::lsearch($w->{_selectionListRef}, $first) >= 0) {
      $w->selectionSet($first)
    }
    $first += 1
  }
}

## Cntrl_backslash
## Deselects all elements
sub Cntrl_backslash {
  my $w = shift;
  my $Ev = $w->XEvent;
  if ($w->cget('-selectmode') ne 'browse') {
    $w->selectionClear(0,'end');
  }
}

## Cntrl_End
## Activates and Selects the last element, scrolling to that
## position if necessary
sub Cntrl_End {
  my $w = shift;
  my $Ev = $w->XEvent;
  $w->activate('end');
  $w->see('end');
  $w->selectionClear(0,'end');
  $w->selectionSet($w->SUPER::index('end - 1 line' ));
}

## Cntrl_Home 
## Activates and Selects the first element, scrolling to that 
## position if necessary
sub Cntrl_Home {
  my $w = shift;
  my $Ev = $w->XEvent;
  $w->activate(0);
  $w->see(0);
  $w->selectionClear(0,'end');
  $w->selectionSet(0)
}

## DataExtend
##
## This procedure is called for key-presses such as Shift-KEndData.
## If the selection mode isn't multiple or extend then it does nothing.
## Otherwise it moves the active element to el and, if we're in
## extended mode, extends the selection to that point.
##
## Arguments:
## w - The listbox widget.
## el - An integer element number.
sub DataExtend {
  my $w = shift;
  my $el = shift;
  my $mode = $w->cget('-selectmode');
  if ($mode eq 'extended') {
    $w->activate($el);
    $w->see($el);
    if ($w->selectionIncludes('anchor')) {
      $w->Motion($el)
    }
  } elsif ($mode eq 'multiple') {
    $w->activate($el);
    $w->see($el)
  }
}

## ExtendUpDown( <amount> )
##
## Does nothing unless we're in extended selection mode; in this
## case it moves the location cursor (active element) up or down by
## one element, and extends the selection to that point.
##
## Arguments:
## w - The listbox widget.
## amount - +1 to move down one item, -1 to move back one item.
sub ExtendUpDown {
  my $w = shift;
  my $amount = shift;

  if ($w->cget('-selectmode') ne 'extended') {
    return;
  }

  ## Compensate for one-based index
  my $index = $w->index('active') - 1;
  if ($index + $amount < 0) {
    $index++;
  } elsif ($index + $amount > $w->index('end') - 2) {
    $index--;
  }

  $w->activate($index + $amount);
  $w->see('active');
  $w->Motion($index + $amount);
}

## FocusIn/FocusOut
sub FocusIn {
  my $w = shift;
  if ($w->cget('-takefocus')) {
    $w->tagConfigure('_ACTIVE_TAG', -underline => 1);
  }
}

sub FocusOut {
  my $w = shift;
  if ($w->cget('-takefocus')) {
    $w->tagConfigure('_ACTIVE_TAG', -underline => 0);
  }
}


## Motion( <element> )
##
## This procedure is called to process mouse motion events while
## button 1 is down. It may move or extend the selection, depending
## on the listbox's selection mode.
##
## Arguments:
## w - The listbox widget.
## curElement - The element under the pointer (must be a number).
sub Motion {
  my $w = shift;
  my $element = shift;

  # This should be the Actual Text Index
  my $curElement = $w->index($element);
  # Compensate for one-base index
  $curElement--; 

  my $selectMode = $w->cget(-selectmode);
  my $prevElement;
    
  ## when the current Element is the same as the previously
  ## element, then as far TextList is concerned we have not
  ## moved 
  if (defined($w->{_prevElement})) {
    $prevElement = $w->{_prevElement};
    if ($curElement == $prevElement) {
      return;
    }
  }
  
  ## For browse, single, and extended modes, if there are
  ## no currently selected items, run through the Begin
  ## BeginSelect method (reuse a little code), then 
  ## return early
  if($w->curselection== 0) {
    $w->BeginSelect($curElement);
    return;
  }

  ## Under 'browse' mode clear anything which has
  ## been selected, then set the current item as
  ## selected
  if ($selectMode eq 'browse') {
    $w->selectionClear(0,'end');
    $w->selectionSet($curElement);
    $w->{_prevElement} = $curElement;

  ## 'Extended Mode', note that single
  ## and multiple modes basically ignore
  ## motion of the mouse
  } elsif ($selectMode eq 'extended') {

    my $anchor = $w->index('anchor');

    ## Compensates for one-based index.
    if (($prevElement == 0) && ($curElement == 1)) {
      if ($anchor != 1) {
        $curElement = 0;
      }
    }   
    if ($w->selectionIncludes('anchor')) {
      $w->selectionClear($prevElement, $curElement);
      $w->selectionSet('anchor', $curElement)

    } else {
      $w->selectionClear($prevElement, $curElement);
      $w->selectionClear('anchor', $curElement)
    }
    while ($prevElement  < $curElement && $prevElement < $anchor) {
      if (Tk::lsearch($w->{_selectionListRef}, $prevElement) >= 0) {
        $w->selectionSet($prevElement)
      }
      $prevElement += 1
    }
    while ($prevElement > $curElement && $prevElement > $anchor) {
      if (Tk::lsearch($w->{_selectionListRef}, $prevElement) >= 0) {
        $w->selectionSet($prevElement)
      }
      $prevElement -= 1
    }
    $w->{_prevElement} = $curElement;
  }
}

## SelectAll
##
## This procedure is invoked to handle the "select all" operation.
## For single and browse mode, it just selects the active element.
## Otherwise it selects everything in the widget.
##
## Arguments:
## w - The listbox widget.
sub SelectAll {
  my $w = shift;
  my $mode = $w->cget('-selectmode');
  if ($mode eq 'single' || $mode eq 'browse') {
    $w->selectionClear(0,'end');
    $w->selectionSet('active')

  } else {
    $w->selectionSet(0,'end')
  }
}

## UpDown( <amount> )
## 
## Moves the location cursor (active element) up or down by one element,
## and changes the selection if we're in browse or extended selection
## mode.
##
## Arguments:
## w - The listbox widget.
## amount - +1 to move down one item, -1 to move back one item.
sub UpDown {
  my $w = shift;
  my $amount = shift;

  ## Compensate for one-based index
  my $index = $w->index('active') - 1;
  if ($index + $amount < 0) {
    $index++;
  } elsif ($index + $amount > $w->index('end') - 2) {
    $index--;
  }

  $w->activate($index + $amount);
  $w->see('active');
  my $selectmode = $w->cget('-selectmode');
  if ($selectmode eq 'browse') {
    $w->selectionClear(0,'end');
    $w->selectionSet('active')

  } elsif ($selectmode eq 'extended') {
    $w->selectionClear(0,'end');
    $w->selectionSet('active');
    $w->selectionAnchor('active');
    $w->{_prevElement} = $index;
    my @list = ();
    $w->{_selectionListRef}=\@list;
  }
}

1;
