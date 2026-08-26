# Coverage matrix summary

Package: geoscales 0.5.0

## Rows by kind x depth

```
Key: <kind>
        kind     U     P     B
      <char> <int> <int> <int>
    argument     7     7    29
    constant     2     0     0
 constructor     6     0     2
        plot     5     0     0
       query    16     2     0
    registry    11     0     0
        verb     5     0     3
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

## Zero-coverage rows (0)

```
Empty data.table (0 rows and 2 cols): name,kind
```

Tagged rows: 4 | inferred: 91 | uncovered: 0 of 95
