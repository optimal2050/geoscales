# Coverage matrix summary

Package: geoscales 0.7.1

## Rows by kind x depth

```
Key: <kind>
        kind  none     U     P     B
      <char> <int> <int> <int> <int>
    argument     0     9     7    34
    constant     0     2     0     0
 constructor     1     5     0     2
        plot     0     5     0     0
       query     1    17     2     0
    registry     0    13     0     0
        verb     0     7     0     3
```

## Backend sweep (from @covers tags)

```
                   fn data.frame tibble data.table dtplyr  arrow
               <char>     <lgcl> <lgcl>     <lgcl> <lgcl> <lgcl>
        join_geoscale       TRUE   TRUE       TRUE   TRUE   TRUE
 recast_from_geoatoms       TRUE   TRUE       TRUE   TRUE   TRUE
      recast_geoscale       TRUE   TRUE       TRUE   TRUE   TRUE
   recast_to_geoatoms       TRUE   TRUE       TRUE   TRUE   TRUE
```

## Zero-coverage rows (2)

```
              name        kind
            <char>      <char>
       ne_geoscale constructor
 is_valid_geoframe       query
```

Tagged rows: 8 | inferred: 98 | uncovered: 2 of 108
