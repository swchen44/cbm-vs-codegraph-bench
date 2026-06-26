# Basic C construct extraction - full

| construct | cbm (label: count) | codegraph (kind: count) | note |
|---|---|---|---|
| struct | Class: 1775 | struct: 706 | cbm has no C Struct label, lumps into Class, count inflated (dups/fwd-decl) |
| enum name | Enum: 336 | enum: 408 | both extract |
| enumerator (enum value) | none (in Variable: 2710) | enum_member: 3244 | codegraph dedicated node; cbm treats enum value as variable |
| function | Function: 9125 | function: 9351 | both near-identical, reliable |
| method | Method: 201 | method: 201 | - |
| typedef | none | type_alias: 104 | codegraph yes, cbm no |
| macro | Macro: 3395 | 0 | cbm extracts macros, codegraph does not |

## inline function recall (static inline in headers)
- sample 20 inline functions: cbm 19 / 20 ; codegraph 20 / 20 (both index inline as function)

## known differences / caveats
- cbm name collision: e.g. wpa_supplicant is simultaneously struct(Class)/dir(Folder)/function; queries need label filter.
- codegraph models C types more finely (struct / enum_member / type_alias distinct); cbm is coarser (struct->Class, enum-value->Variable, no typedef label).
