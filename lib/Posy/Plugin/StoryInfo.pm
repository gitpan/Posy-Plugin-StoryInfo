package Posy::Plugin::StoryInfo;
use strict;

=head1 NAME

Posy::Plugin::StoryInfo - Posy plugin which gets suplementary information about stories from the story-entry itself.

=head1 VERSION

This describes version B<0.02> of Posy::Plugin::StoryInfo.

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
	...
	Posy::Plugin::Info
	Posy::Plugin::StoryInfo
	...);

=head1 DESCRIPTION

This plugin is an augmentation and specialization of Posy::Plugin::Info
in that it extracts specialized Info data from the entry itself.
This expects that the entry is a story, and therefore has a Title
and an Author (and possibly a Summary and an AuthorEmail).  Since
stories often tend have some conventions in formatting this particular
information, this plugin tries to guess that information from the
story-entry itself, if the entry is HTML or plain text.
This is only done, however, if the entry doesn't
already have a .info file associated with it.

This expects Posy::Plugin::Info to also be installed.

This plugin replaces the 'info' method.

Note that this is not reccommended as a permanent setup, since .info
files have been designed to be smaller and easier to parse, and
extracting Info from entry-files will take longer than having
the Info in .info files.  It is, however, useful for extracting
the initial information from the entry file, so it can then
be put into an .info file.

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the config directory.

=over

=item B<story_info_on>

If true, enable extraction of Info information from entries.
(default: false)

=item B<story_info_title_name>

The name of the Info field into which to put the Title information.
(default: Title)  Make it empty to not use this field.

=item B<story_info_author_firstname>

The name of the Info field into which to put the author's first-name
information is put.  (default: Firstname)  Make it empty to not use this field.

=item B<story_info_author_lastname>

The name of the Info field into which to put the author's last-name
information is put.  (default: Lastname)  Make it empty to not use this field.

=item B<story_info_author_email>

The name of the Info field into which to put the author's email
information is put.  (default: AuthorEmail)  Make it empty to not use this field.

=item B<story_info_size_name>

The name of the Info field into which to put the Size information (number
of K) (default: Size)  Make it empty to not use this field.

=item B<story_info_fields>

Define additional fields to look for.  The first part of the definition
is the name of the Info field, and the second part is the string to look for
which will contain the required information after it.

    story_info_fields:
      Summary: 'Summary:'
      Category: 'Category:'
      Rating: 'Rating:'

This is really rather limited, but it does work with common formats.

=back

=cut

=head1 OBJECT METHODS

Documentation for developers and those wishing to write plugins.

=head2 init

Do some initialization; make sure that default config values are set.

=cut
sub init {
    my $self = shift;
    $self->SUPER::init();

    # set defaults
    $self->{config}->{story_info_on} = 0
	if (!defined $self->{config}->{story_info_on});
    $self->{config}->{story_info_title_name} = 'Title'
	if (!defined $self->{config}->{story_info_title_name});
    $self->{config}->{story_info_author_firstname} = 'Firstname'
	if (!defined $self->{config}->{story_info_author_firstname});
    $self->{config}->{story_info_author_lastname} = 'Lastname'
	if (!defined $self->{config}->{story_info_author_lastname});
    $self->{config}->{story_info_author_email} = 'AuthorEmail'
	if (!defined $self->{config}->{story_info_author_email});
    $self->{config}->{story_info_size_name} = 'Size'
	if (!defined $self->{config}->{story_info_size_name});
    $self->{config}->{story_info_fields} = {}
	if (!defined $self->{config}->{story_info_fields});
} # init

=head1 Helper Methods

Methods which can be called from within other methods.

=head2 info

    my %vars = $self->info($entry_id);

Gets the .info fields related to the given entry.

    my $val = $self->info($entry_id, field=>$name);

Get the value of the given .info field for this entry.

=cut
sub info {
    my $self = shift;
    my $entry_id = shift;
    my %args = (
	field=>undef,
	@_
    );
    if ($self->{config}->{story_info_on})
    {
	# only look for story-info if the .info file doesn't exist
	my $look_file = File::Spec->catfile($self->{data_dir}, "$entry_id.info");
	if (!-f $look_file)
	{
	    my %info = ();
	    # get the full info hash
	    if (exists $self->{info}->{$entry_id}
		and defined $self->{info}->{$entry_id})
	    {
		my $info_ref = $self->{info}->{$entry_id};
		%info = %{$info_ref};
	    }
	    elsif (!exists $self->{info}->{$entry_id})
	    {
		%info = $self->_story_info_get_info($entry_id);
		$self->{info}->{$entry_id} = (%info ? \%info : undef);
	    }
	    if ($args{field})
	    {
		if (exists $info{$args{field}}
		    and defined $info{$args{field}})
		{
		    $self->debug(3, "info{$args{field}}: $info{$args{field}}");
		    return $info{$args{field}};
		}
	    }
	    else
	    {
		return %info;
	    }
	}
	else
	{
	    return $self->SUPER::info($entry_id, %args);
	}
    }
    else
    {
	return $self->SUPER::info($entry_id, %args);
    }

    return undef;
} # info

=head1 Private Methods

These methods may or may not be here in the future.

=head2 _story_info_get_info

    my %info = $self->story_info_get_info($entry_id);

Parse Info information from an entry file, assuming
that it's a "story".

=cut
sub _story_info_get_info {
    my $self = shift;
    my $entry_id = shift;

    $self->debug(2, "_story_info_get_info: $entry_id");
    my %info;
    if (-r $self->{files}->{$entry_id}->{fullname})
    {
	if ($self->{config}->{story_info_size_name})
	{
	    # get the file size in K
	    my ($size) = (stat ($self->{files}->{$entry_id}->{fullname})) [7];
	    $size /= 1024;
	    $info{$self->{config}->{story_info_size_name}} = int($size);
	}

	# check the file type
	my $file_type = $self->{file_extensions}->{$self->{files}->{$entry_id}->{ext}};
	if ($file_type eq 'html')
	{
	    $self->_story_info_extract_info_from_html($entry_id, \%info);
	}
	elsif ($file_type eq 'text')
	{
	    $self->_story_info_extract_info_from_text($entry_id, \%info);
	}
	return %info;
    }
    return ();
} # _story_info_get_info

=head2 _story_info_extract_info_from_html

Extract info from a HTML entry file.

=cut

sub _story_info_extract_info_from_html {
    my $self = shift;
    my $entry_id = shift;
    my $info_ref = shift;

    my $filename = $self->{files}->{$entry_id}->{fullname};
    my $fh;
    if (!open ($fh, $filename))
    {
	warn "Error: unable to open ", $filename, ": $!\n";
	return 0;
    }

    require HTML::SimpleParse;

    # Read the file
    my $html_str = "";
    {
	local $/;
	$html_str = <$fh>;
	close ($fh);
    }

    # parse the file
    my $hp = new HTML::SimpleParse();
    $hp->text($html_str);
    $hp->parse();

    my $authorname = '';
    my $title = '';
    my $author_email = '';
    my $tag;
    my $content;

    my $tok;
    my $next_tok;
    my @tree = $hp->tree();
    while (@tree) {
	$tok = shift @tree;
	$next_tok = $tree[0];
	# check titles for titles
	if ($tok->{type} eq 'starttag'
	    && $tok->{content} =~ /title/i)
	{
	    $title = $next_tok->{content};
	}
	# assume the first email we find is the author's
	elsif ($tok->{type} eq 'starttag'
		&& $tok->{content} =~ /^A/i)
	{
	    if (!$author_email)
	    {
		my $email = '';
		if ($tok->{content} =~ /href=\"mailto:([^\"]*)\"/)
		{
		    $email = $1;
		}
		elsif ($tok->{content} =~ /href=mailto:(.*)/)
		{
		    $email = $1;
		}
		if (!$author_email && $email)
		{
		    $email =~ s/^[    \n]*//;
		    $email =~ s/[    \n]*$//;
		    $author_email = $email;
		}
	    }
	} # anchor
	# check paragraphs for summaries and other things
	elsif ($tok->{type} eq 'starttag'
		&& ($tok->{content} =~ /^P/i
		    || $tok->{content} =~ /^DIV/i
		    || $tok->{content} =~ /^BLOCKQUOTE/i
		    || $tok->{content} =~ /^H2/i
		    || $tok->{content} =~ /^BR$/i))
	{
	    # extract the text from this paragraph and check it
	    $content = '';
	    while (@tree) {
		$tok = shift @tree;
		$next_tok = $tree[0];
		# Text
		if ($tok->{type} eq 'text') {
		    $content .= $tok->{content};
		}
		# end of the paragraph/section
		if (($tok->{type} eq 'endtag'
		    && ($tok->{content} =~ /^P$/i
			|| $tok->{content} =~ /^DIV/i
			|| $tok->{content} =~ /^BLOCKQUOTE/i
			|| $tok->{content} =~ /^H2/i
			))
		    || ($next_tok->{type} eq 'starttag'
			&& $next_tok->{content} =~ /^BR$/i)
		    || ($next_tok->{type} eq 'starttag'
			&& $next_tok->{content} =~ /^P/i)
		    || ($next_tok->{type} eq 'starttag'
			&& $next_tok->{content} =~ /^HR$/i)
		    || ($next_tok->{type} eq 'starttag'
			&& $next_tok->{content} =~ /^A$/i)
		    )
		{
		    $content =~ s/^[    \n]*//;
		    $content =~ s/[    \n]*$//;

		    while (my ($field, $match) = each (%{$self->{config}->{story_info_fields}}))
		    {
			if (!$info_ref->{$field}
			    && $content =~ /^$match(.+)/i)
			{
			    $info_ref->{$field} = $1;
			    $info_ref->{$field} =~ s/^[    \n]*//;
			    $info_ref->{$field} =~ s/[    \n]*$//;
			}
		    }
		    # also look for Title and Author
		    if (!$title
			&& $content =~ /^Title:/i)
		    {
			$content =~ s/^Title://i;
			$content =~ s/^[    \n]*//;
			$content =~ s/[    \n]*$//;
			$title = $content;
		    }
		    if (!$authorname
			&& $content =~ /^Author:/i)
		    {
			$content =~ s/^Author://i;
			$content =~ s/^[    \n]*//;
			$content =~ s/[    \n]*$//;
			$authorname = $content;
		    }
		    elsif (!$authorname
			&& $content =~ /^by /i)
		    {
			$content =~ s/^by //i;
			$content =~ s/^[    \n]*//;
			$content =~ s/[    \n]*$//;
			$authorname = $content;
		    }
		    if (!$author_email
			&& $content =~ /^Email:/i)
		    {
			$content =~ s/^Email://i;
			$content =~ s/^[    \n]*//;
			$content =~ s/[    \n]*$//;
			$author_email = $content;
		    }
		    last;
		}
	    } # while looking at para
	} # para or break?
    }
    # post-process Title
    if ($title =~ /^([^,]*), by (.*)$/)
    {
	$title = $1;
	$authorname = $2;
    }
    elsif ($title =~ /^([^\(]*) \(by (.*)\)$/)
    {
	$title = $1;
	$authorname = $2;
    }
    elsif ($title =~ /^(.*) by (.*)$/)
    {
	$title = $1;
	$authorname = $2;
    }
    $title =~ s/[    \n]*$//;
    # post-process Author
    $authorname =~ s/^[    \n]*//;
    $authorname =~ s/[    \n]*$//;
    my $firstname;
    my $lastname;
    if ($authorname =~ /^([a-zA-Z0-9]+) ([^ ]*)$/)
    {
	$firstname = $1;
	$lastname = $2;
    }
    else
    {
	$firstname = $authorname;
	$lastname = '';
    }
    # set the Title Author etc info ref
    if ($self->{config}->{story_info_title_name})
    {
	$info_ref->{$self->{config}->{story_info_title_name}} = $title;
    }
    if ($self->{config}->{story_info_author_firstname})
    {
	$info_ref->{$self->{config}->{story_info_author_firstname}} = $firstname;
    }
    if ($self->{config}->{story_info_author_lastname})
    {
	$info_ref->{$self->{config}->{story_info_author_lastname}} = $lastname;
    }
    if ($self->{config}->{story_info_author_email})
    {
	$info_ref->{$self->{config}->{story_info_author_email}} = $author_email;
    }
    return 1;
} # _story_info_extract_info_from_html

=head2 _story_info_extract_info_from_text

Extract info from a text entry file.

=cut

sub _story_info_extract_info_from_text {
    my $self = shift;
    my $entry_id = shift;
    my $info_ref = shift;

    my $filename = $self->{files}->{$entry_id}->{fullname};
    my $fh;
    if (!open ($fh, $filename))
    {
	warn "Error: unable to open ", $filename, ": $!\n";
	return 0;
    }

    my $authorname = '';
    my $title = '';
    my $author_email = '';

    # Read and parse the file
    my $prev_line = '';
    while (<$fh>)
    {
	s/\n//;
	s/\r//;
	# Title?
	if (/Title:\s*(.+)/)
	{
	    $title = $1;
	}
	elsif (/Subject:\s*(.+)/)
	{
	    $title = $1;
	}
	# assume the first email we find is the author's
	elsif (/(\S+\@\S+)/)
	{
	    my $email = $1;

	    if (!$author_email && $email)
	    {
		$email =~ s/^[    \n]*//;
		$email =~ s/[    \n]*$//;
		$author_email = $email;
	    }
	}
	elsif (/Author:\s*(.+)/)
	{
	    $authorname = $1;
	}
	# assume the first "by" is the author
	elsif (/^\s*[Bb]y\s*(.+)/)
	{
	    if (!$authorname)
	    {
		$authorname = $1;
		# the line before may well be the title
		if (!$title)
		{
		    $title = $prev_line;
		}
	    }
	}
	while (my ($field, $match) = each (%{$self->{config}->{story_info_fields}}))
	{
	    if (!$info_ref->{$field}
		&& /^$match(.+)/i)
	    {
		$info_ref->{$field} = $1;
		$info_ref->{$field} =~ s/^[    \n]*//;
		$info_ref->{$field} =~ s/[    \n]*$//;
	    }
	}
	$prev_line = $_;
    }
    close ($fh);

    # post-process Author
    $authorname =~ s/^[    \n]*//;
    $authorname =~ s/[    \n]*$//;
    my $firstname;
    my $lastname;
    if ($authorname =~ /^([a-zA-Z0-9]+) ([^ ]*)$/)
    {
	$firstname = $1;
	$lastname = $2;
    }
    else
    {
	$firstname = $authorname;
	$lastname = '';
    }
    # set the Title Author etc info ref
    if ($self->{config}->{story_info_title_name})
    {
	$info_ref->{$self->{config}->{story_info_title_name}} = $title;
    }
    if ($self->{config}->{story_info_author_firstname})
    {
	$info_ref->{$self->{config}->{story_info_author_firstname}} = $firstname;
    }
    if ($self->{config}->{story_info_author_lastname})
    {
	$info_ref->{$self->{config}->{story_info_author_lastname}} = $lastname;
    }
    if ($self->{config}->{story_info_author_email})
    {
	$info_ref->{$self->{config}->{story_info_author_email}} = $author_email;
    }
    return 1;
} # _story_info_extract_info_from_text

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::StoryInfo

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules.

Therefore you will need to change the PERL5LIB variable to add
/home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

=head1 REQUIRES

    Posy
    Posy::Core
    Posy::Plugin::Info
    HTML::SimpleParse

    Test::More

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::StoryInfo
__END__
