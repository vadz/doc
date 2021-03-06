use v6;
use Perl6::TypeGraph;

class Perl6::TypeGraph::Viz {
    has @.types;
    has $.dot-hints;
    has $.url-base    = '../type/';
    has $.rank-dir    = 'BT';
    has $.role-color  = '#6666FF';
    has $.class-color = '#000000';
    has $.node-soft-limit = 20;
    has $.node-hard-limit = 50;

    method new-for-type ($type) {
        my $self = self.bless(*, :types([$type]));
        $self!add-neighbors;
        return $self;
    }

    method !add-neighbors {
        # Add all ancestors (both class and role) to @.types
        sub visit ($n) {
            state %seen;
            return if %seen{$n}++;
            visit($_) for $n.super, $n.roles;
            @!types.push: $n;
        }

        # Work out in all directions from @.types,
        # trying to get a decent pool of type nodes
        my @seeds = @.types, @.types>>.sub, @.types>>.doers;
        while (@.types < $.node-soft-limit) {
            # Remember our previous node set
            my @prev = @.types;

            # Add ancestors of all seeds to the pool nodes
            visit($_) for @seeds;
            @.types .= uniq;

            # Find a new batch of seed nodes
            @seeds = uniq(@seeds>>.sub, @seeds>>.doers);

            # If we're not growing the node pool, stop trying
            last if @.types <= @prev or !@seeds;

            # If the pool got way too big, drop back to previous
            # pool snapshot and stop trying
            if @.types > $.node-hard-limit {
                @.types = @prev;
                last;
            }
        }
    }

    method as-dot (:$size) {
        my @dot;
        @dot.push: "digraph \"perl6-type-graph\" \{\n    rankdir=$.rank-dir;\n    splines=polyline;\n";
        @dot.push: "    size=\"$size\"\n" if $size;

        if $.dot-hints {
            @dot.push: "\n    // Layout hints\n";
            @dot.push: $.dot-hints;
        }

        @dot.push: "\n    // Types\n";
        for @.types -> $type {
            my $color = $type.packagetype eq 'role' ?? $.role-color !! $.class-color;
            @dot.push: "    \"$type.name()\" [color=\"$color\", fontcolor=\"$color\", href=\"{$.url-base ~ $type.name ~ '.html' }\"];\n";
        }

        @dot.push: "\n    // Superclasses\n";
        for @.types -> $type {
            for $type.super -> $super {
                @dot.push: "    \"$type.name()\" -> \"$super\" [color=\"$.class-color\"];\n";
            }
        }

        @dot.push: "\n    // Roles\n";
        for @.types -> $type {
            for $type.roles -> $role {
                @dot.push: "    \"$type.name()\" -> \"$role\" [color=\"$.role-color\"];\n";
            }
        }

        @dot.push: "\}\n";
        return @dot.join;
    }

    method to-dot-file ($file) {
        spurt $file, self.as-dot;
    }

    method to-file ($file, :$format = 'svg', :$size) {
        my $pipe = open "dot -T$format -o$file", :w, :p;
        $pipe.print: self.as-dot(:$size);
        close $pipe;
    }
}
