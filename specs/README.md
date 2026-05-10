# Specs and golden tests (cross-language)

Language-agnostic input/output pairs and named region hierarchies. All three
language implementations (R, C++, Python) load fixtures from this directory
and must reproduce identical results.

## Planned layout

```
specs/
├── regions/              # named region hierarchies in YAML
└── golden/               # input → expected-output pairs
    ├── 001-basic-nesting/
    │   ├── input.yaml
    │   └── expected.csv
    └── ...
```

When you change observable behaviour, update the spec and per-language tests in
the same PR.
