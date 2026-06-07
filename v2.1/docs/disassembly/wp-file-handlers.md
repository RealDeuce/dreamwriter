# Word-Processor FILE Handlers

This slice expands the `FILE` submenu handler roots from
[`wp-submenus.md`](wp-submenus.md). The six menu entries do not form six
independent applications. They share one storage UI layer: resource-backed
screen prompts, a current directory/file picker, a filename-entry descriptor at
`[75EF]`, and common buffers at `7555`, `778A`, `778E`, and `779A`.

The lower DOS-like file API and storage endpoints are documented in
[`../file-system.md`](../file-system.md), and the low-level `DC98` wrappers are
documented in [`dc98-file-wrappers.md`](dc98-file-wrappers.md).

## Handler Roots

| Menu item | Icon | Wrapper | Inner root | File offset | Role |
| --- | --- | --- | --- | ---: | --- |
| `RECALL` | ![RECALL](images/wp-file-recall-0x6ea4a.png) | `C688:EB2E` | `C688:7B41` | `0x4E3C1` | Pick a document and load/insert it into editor state. |
| `STORE` | ![STORE](images/wp-file-store-0x6e982.png) | `C688:EBD9` | `C688:7C1D` | `0x4E49D` | Prompt for a filename, optionally overwrite/secret-mark, then store the current document. |
| `DELETE` | ![DELETE](images/wp-file-delete-0x6eb12.png) | `C688:EBA9` | `C688:790E` | `0x4E18E` | Pick a document, confirm, then delete it. |
| `RENAME` | ![RENAME](images/wp-file-rename-0x6ebda.png) | `C688:EBC1` | `C688:7A1B` | `0x4E29B` | Pick a document and edit its replacement 8.3-style name. |
| `COPY` | ![COPY](images/wp-file-copy-0x6f21a.png) | none | `DC98:455F` | `0x60EDF` | Select source/destination direction, then enter the multi-select copy list. |
| `INITIALIZE` | ![INITIALIZE](images/wp-file-initialize-0x6f2e2.png) | `C688:EB91` | `C688:7993` | `0x4E213` | Confirm and invoke the private format path for the active storage target. |

The five `C688:EBxx` far wrappers are all the same app-wrapper shape: save
registers, set `ES=0A4F`, call the inner root, restore registers, and return
`AL=[794A]`, `AH=0`.

```asm
; C688:EB2E / file 0x553AE, representative wrapper
C688:EB2E  push cx
C688:EB2F  push dx
C688:EB30  push si
C688:EB31  push di
C688:EB32  push bp
C688:EB33  mov  bp,0A4F
C688:EB36  mov  es,bp
C688:EB38  call C688:7B41        ; RECALL root
...
C688:EB41  mov  al,[794A]
C688:EB44  xor  ah,ah
C688:EB46  retf
```

## Shared UI Layer

The common C688 storage UI is centered on these helpers:

| Helper | File offset | Use |
| --- | ---: | --- |
| `C688:7689` | `0x4DF09` | Draws a numbered display resource selected by `SI`. It clears/setup state, loads the resource through `C688:9541`, and enters the screen/list setup path. |
| `C688:7789` / `C688:77C1` | `0x4E009` / `0x4E041` | Resource display variants used while prompts are already active. |
| `C688:7841` | `0x4E0C1` | Resolves the current picker selection and returns a directory-entry pointer in `BX`; selected flags are read from `[BX+04]`. |
| `C688:788A` / `C688:788D` | `0x4E10A` / `0x4E10D` | Build the edit/list descriptor: mode in `[750F]`, buffer pointer in `[750B]`, max length in `[750D]`, and descriptor pointer `[7506]=750F`. |
| `C688:7DE1` | `0x4E661` | Seeds the filename/current-label buffer with `778A[0]='1'` and `778A[10h]='A'`. |
| `C688:81A1` | `0x4EA21` | Common directory/list setup. Calls `C688:EF0B`, then `C688:7DEE`. |
| `C688:81A8` | `0x4EA28` | Directory/list setup plus picker refresh through `C688:913F`, preserving `[75EF]`. |
| `C688:81B7` | `0x4EA37` | Flag-`0x04` selected-file check. Calls `DC98:2887`, draws resource `0x8D`, and returns zero/nonzero status. |
| `C688:81C9` | `0x4EA49` | Re-resolves the selected entry and applies the `C688:81B7` flag-`0x04` check when needed. |
| `C688:82A6` | `0x4EAA6` | Validates/normalizes an 8.3-like name field, blank-padding the remainder. |
| `C688:82FF` | `0x4EAFF` | Runs the filename-entry selector with `CL=1`, preserving `[75EF]`, and returns `[794A]`. |
| `C688:8312` | `0x4EB92` | Small yes/no style input dispatcher used by the secret-file prompt and other modal prompts. |
| `C688:9187` | `0x4FA07` | Shared document picker entry. Calls `DC98:52E5` with `AL=[6806]|40`, `BX=7555`, then copies the selected name into `778E`. |
| `C688:92DF` | `0x4FB5F` | Inline key dispatch primitive. Many handlers point `[75EF]` at a local table and let this rewrite the return path from `[794A]`. |

The main shared buffers are:

| Address | Use |
| --- | --- |
| `[6805]` | Base/current local storage endpoint. COPY uses it to derive direction choices. |
| `[6806]` | Active storage target. The picker passes `[6806] | 0x40` to `DC98:52E5`. |
| `[794A]` | Last key/event byte returned to the submenu wrapper. |
| `[75EF]` | Pointer to the current inline key-dispatch or edit-field descriptor. |
| `7555` | Scratch filename/input buffer. STORE and RENAME validate this buffer before committing. |
| `778A` | Current picker/current document filename buffer. |
| `778E` | Selected or edited 12-byte filename field. |
| `8DFC` | Current document name slot; RECALL copies `778A -> 8DFC`, STORE copies `8DFC -> 778A`. |

## DELETE

`DELETE` is the smallest complete picker-confirm-action flow.

```asm
; C688:790E / file 0x4E18E
C688:790E  mov  si,0072
C688:7911  call C688:7689        ; DELETE FILE directory screen
C688:7914  call C688:81A1        ; common directory/list setup
C688:7917  call C688:9187        ; picker
C688:791A  jc   C688:7968
C688:791C  cmp  al,09
C688:791E  jz   C688:790B       ; TAB changes directory, then redraw
C688:7920  call C688:7DE1
C688:7923  mov  al,[794A]
C688:7926  cmp  al,DA
C688:7928  jnz  C688:7968
C688:792A  call C688:7841        ; selected directory entry
C688:7931  mov  al,[bx+04]
C688:7934  test al,04
C688:7938  call C688:81B7        ; extra check for flag 0x04
...
C688:7946  mov  si,0073
C688:7949  call C688:7689        ; "Are you sure?"
...
C688:7978  mov  si,0074
C688:797B  call C688:7689        ; "Deleting file"
C688:797E  call C688:7541        ; delete operation
C688:7985  call C688:96E1
C688:7988  call C688:9702
C688:798B  jmp  C688:790E
```

Resource descriptors:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x72` | `0x0DE1` | `0x567A3` | `0x00B5` | `DIRECTORY` / `DELETE FILE`; instructions: position cursor, press select to delete, press TAB to change directory, press CAN to cancel. |
| `0x73` | `0x0E98` | `0x5685A` | `0x0042` | `DELETE FILE: <selected-name>` and `Are you sure? (Y/N): <field>`. |
| `0x74` | `0x0EDC` | `0x5689E` | `0x0029` | `Deleting file` and `*** WAIT! ***`. |

Final prompt text:

```text
DIRECTORY
DELETE FILE

Position cursor to a file
Press <DA> to delete the file
Press TAB to change Directory
(Built-in, Card or Dreamlink)
Press CAN to cancel
```

```text
DELETE FILE: <selected-name>

Are you sure? (Y/N): <input>
```

## INITIALIZE

`INITIALIZE` shares the same target-selection shell, but ends at the private
format path instead of a file operation.

```asm
; C688:7993 / file 0x4E213
C688:7993  mov  si,0016
C688:7996  call C688:7689        ; initialize warning/directory screen
C688:7999  call C688:81A1
C688:799C  call C688:9131        ; target/directory selector
C688:799F  jc   C688:79F8
C688:79A1  cmp  al,09
C688:79A3  jz   C688:7990       ; TAB redraw/change directory
...
C688:79CC  call C688:EF6B        ; compare/resolve selected target
C688:79D1  mov  si,009D
C688:79D4  call C688:7689        ; DreamLink diskette init status
...
C688:79DC  call C688:EE98
C688:79DF  mov  si,0060
C688:79E2  call C688:EE84        ; built-in memory confirmation
C688:79E5  cmp  al,01
C688:79E7  jnz  C688:79F8
C688:79E9  mov  si,0017
C688:79EC  call C688:7689        ; "Initializing Store Memory"
C688:79EF  call C688:7DE1
C688:79F2  call C688:754A        ; format/write path
C688:79F5  call C688:7D1F        ; cache/status cleanup
```

Resource descriptors:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x16` | `0x043A` | `0x55DFC` | `0x00DB` | `INITIALIZE MEMORY`, `DIRECTORY`, warnings, directory-change instructions, and `(Y/N)` confirmation. |
| `0x17` | `0x0517` | `0x55ED9` | `0x0051` | `Initializing Store Memory`, `*** WAIT! ***`, and `memory size:      kbytes`. |
| `0x60` | `0x185F` | `0x57221` | `0x00B5` | `INITIALIZE BUILT-IN MEMORY`; warning that all built-in files will be lost; asks for `CTRL + WP`. |
| `0x9D` | `0x245A` | `0x57E1C` | `0x0062` | `Initializing DreamLink Diskette`, wait/cancel prompt. |

Final warning text:

```text
INITIALIZE MEMORY
DIRECTORY

Press CAN to cancel
Press TAB to change Directory
(Built-in, Card or Dreamlink)

*** WARNING! *** Initializing will erase any
existing files. Are you sure? (Y/N): <input>
```

## RENAME

`RENAME` shows the clearest use of `[75EF]` as an inline control-flow table.
The local table at `C688:79FD` feeds `C688:92DF`; the table's target labels
advance through "pick old name", "enter new name", "validate", and "commit".

```asm
; C688:7A1B / file 0x4E29B
C688:7A1B  mov  si,778E
C688:7A1E  xor  al,al
C688:7A20  mov  [si],al
C688:7A22  call C688:8199        ; common RENAME prompt setup
C688:7A25  call C688:913F        ; picker variant
C688:7A28  jc   C688:7A4C
C688:7A2A  cmp  al,09
C688:7A2C  jz   C688:7A18
C688:7A2E  call C688:7795
C688:7A31  mov  word [75EF],79FD
C688:7A37  mov  si,0069
C688:7A3A  call C688:7DE1
C688:7A3D  mov  cl,01
C688:7A3F  call C688:921C
C688:7A42  mov  al,[794A]
C688:7A45  cmp  al,09
C688:7A47  jz   C688:7A18
C688:7A49  jmp  C688:928D       ; inline key dispatch
```

After selection it rejects flag bit `0x01`, performs the flag-`0x04` check,
draws the old/new filename fields, validates `7555` through `C688:82A6`, checks
for a same-name collision, and commits through `C688:7545`.

Resource descriptors:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x69` | `0x0FB9` | `0x5697B` | `0x003D` | `OLD FILE NAME: <old-name>` and `NEW FILE NAME: <input>`. |
| `0x6A` | `0x0FF8` | `0x569BA` | `0x0029` | `Renaming file` and `*** WAIT! ***`. |
| `0x6B` | `0x1023` | `0x569E5` | `0x0005` | Small inline continuation field for the rename prompt. |
| `0x6C` | `0x102A` | `0x569EC` | `0x0010` | New-name edit field descriptor. |
| `0x6D` | `0x103C` | `0x569FE` | `0x001B` | `Same file name exists`. |

Final prompt text:

```text
OLD FILE NAME: <old-name>
NEW FILE NAME: <input>
```

## RECALL

`RECALL` uses the shared picker, then either clears working text and recalls the
file or inserts the file into the existing editor buffer.

```asm
; C688:7B41 / file 0x4E3C1
C688:7B41  mov  si,0062
C688:7B44  call C688:7689        ; RECALL FILE directory screen
C688:7B47  call C688:81A1
C688:7B4A  call C688:9187
C688:7B4D  jc   C688:7B3D
C688:7B4F  cmp  al,09
C688:7B51  jz   C688:7B3E
C688:7B53  call C688:7DE1
C688:7B56  mov  al,[794A]
C688:7B59  cmp  al,DA
C688:7B5B  jnz  C688:7B3D
C688:7B5D  call C688:7841
C688:7B64  mov  al,[bx+04]
C688:7B69  test bl,01
C688:7B70  test bl,04
C688:7B83  call C688:8610
C688:7B86  call C688:4F63        ; load/insert document stream
...
C688:7B92  mov  si,0061
C688:7B95  call C688:EE84        ; existing text prompt
...
C688:7BA8  call C688:7766        ; clear/redraw path for overwrite recall
C688:7BAB  call C688:7BC6        ; copy 778A -> 8DFC
```

Resource descriptors:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x61` | `0x1916` | `0x572D8` | `0x0087` | Existing-text choice: clear and recall, insert, or cancel. |
| `0x62` | `0x0C06` | `0x565C8` | `0x00B9` | `DIRECTORY`, `RECALL FILE`, picker instructions, TAB directory change, CAN cancel. |
| `0x64` | `0x0D52` | `0x56714` | `0x002A` | `Recalling file` and `*** WAIT! ***`. |
| `0x65` | `0x0D7E` | `0x56740` | `0x0061` | `Recalling and inserting file to the last cursor position in the text`, wait prompt. |

Final existing-text prompt:

```text
Text exists in work memory
Press <DA> to clear text and recall the file
Press INS to insert the file
(<DA> / INS): <input>
```

## STORE

`STORE` is the inverse of `RECALL`: it first copies the current document name
from `8DFC` to the picker/name buffer at `778A`, then enters the name editor
and finally calls the store path.

```asm
; C688:7C1D / file 0x4E49D
C688:7C1D  mov  si,006F
C688:7C20  mov  ch,03
C688:7C22  call C688:EE9E        ; STORE TEXT screen variant
C688:7C25  call C688:81A8
C688:7C28  jc   C688:7C6A
C688:7C2A  cmp  al,09
C688:7C2C  jz   C688:7C1A
C688:7C2E  call C688:7795
C688:7C31  mov  si,8DFC
C688:7C34  mov  di,778A
C688:7C37  mov  cx,0011
C688:7C41  rep  movsb           ; current document name -> file buffer
C688:7C46  mov  word [75EF],7BFD
C688:7C4C  call C688:7DE1
C688:7C4F  mov  si,0071
C688:7C52  call C688:82FF        ; filename-entry field
C688:7C55  cmp  al,09
C688:7C57  jz   C688:7C1A
C688:7C59  jmp  C688:928D
```

On select, `STORE` validates `778E`, checks whether the target filename already
exists, prompts for overwrite through resource `0x36`, asks whether to mark the
file secret via resources `0x96..0x98`, then draws `0x6E` and calls `C688:7308`
for the actual store operation.

Resource descriptors:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x36` | `0x114A` | `0x56B0C` | `0x003B` | `File name already exists` and `Overwrite? (Y/N): <input>`. |
| `0x6E` | `0x1059` | `0x56A1B` | `0x002B` | `Storing text` and `*** WAIT! ***`. |
| `0x6F` | `0x1086` | `0x56A48` | `0x0041` | `DIRECTORY`, `STORE TEXT as a file`, and `ENTER FILE NAME:`. |
| `0x71` | `0x1137` | `0x56AF9` | `0x0011` | Filename edit-field descriptor for `STORE`. |
| `0x96` | `0x22D5` | `0x57C97` | `0x002C` | `Do you want to make the file as secret?`. |
| `0x97` | `0x2303` | `0x57CC5` | `0x000F` | Yes/No choice with `No` selected. |
| `0x98` | `0x2314` | `0x57CD6` | `0x000F` | Yes/No choice with `Yes` selected. |

Final prompt text:

```text
DIRECTORY
STORE TEXT as a file

ENTER FILE NAME: <input>
```

```text
File name already exists
Overwrite? (Y/N): <input>
```

```text
Do you want to make the file
as secret?

Yes    No
```

## COPY

`COPY` is the one FILE entry that stays in the `DC98` segment. `DC98:455F`
starts with a normal stack frame at file `0x60EDF`; the earlier apparent
epilogue mismatch was just a bad physical skip.

```asm
; DC98:455F / file 0x60EDF
DC98:455F  push bp
DC98:4560  mov  bp,sp
DC98:4562  sub  sp,080E
DC98:4568  mov  ax,0000
DC98:456B  mov  es,ax
DC98:456D  mov  al,[es:6805]
DC98:4573  mov  bl,[6806]
DC98:4579  sub  bx,ax
DC98:457B  add  bx,0040
DC98:457E  mov  [bp-0E],bx      ; current direction index
DC98:458C  call DC98:0E70       ; display/setup clear
DC98:4591  mov  ax,0002
DC98:4594  mov  bx,EFF0
DC98:4597  xor  cx,cx
DC98:4599  xor  dx,dx
DC98:459B  call DC98:0E81       ; draw direction selector
DC98:45A0  lea  ax,[bp-080E]
DC98:45A4  call DC98:41D8       ; copy list/direction UI
```

When `DC98:41D8` returns `0x03` or `0x0B`, `COPY` commits the selected direction
back into `[6806]` by adding the selected direction index to `[6805]` and
subtracting `0x40`. `TAB` cycles the direction index, wrapping after `2`, and
then redraws the selector.

The copy UI cluster begins at file `0x6FF03` / effective `0xEFF03`. Its string
records include:

```text
COPY
SPACE  select/deselect a file
INS    select all
BACK   deselect all
TAB    change direction
<DA>   start
CAN    cancel

Direction  : Built-in -> Card
Direction  : Card -> Built-in
Direction  : Built-in -> DreamLink
Direction  : DreamLink -> Built-in
```

The list routine below `DC98:41D8` is a multi-select file list: space toggles
the mark on the current entry, `0x0D` marks all, `0x08` clears all, arrow keys
move by row/column, and `0xDA` starts copying the marked set. The actual
open/read/write/error paths underneath are the same DOS-like API layer already
mapped in [`dc98-file-wrappers.md`](dc98-file-wrappers.md).

## Error Prompt Layer

Several FILE handlers funnel nonzero action results through `C688:7D28`, which
maps status values to message resources, draws resource `0x2E` first, then
draws the selected message and waits for CAN or TAB.

```asm
C688:7D28  call C688:92E2        ; dispatch AL through inline table
...
C688:7D5C  mov  si,009A         ; only Built-in memory is available
C688:7D63  mov  si,009C         ; DreamLink not connected
C688:7D68  mov  si,009B         ; DreamLink connection error
...
C688:7D9D  push si
C688:7D9E  mov  si,002E
C688:7DA1  call C688:7689
C688:7DA4  pop  si
C688:7DA5  call C688:7689
C688:7DCE  mov  cl,01
C688:7DD0  call C688:71A4
```

Representative error/status resources:

| ID | Table word | Payload | Length | Final formatted text |
| ---: | ---: | ---: | ---: | --- |
| `0x9A` | `0x2338` | `0x57CFA` | `0x004D` | `Only Built-in memory is available`; `Press CAN to exit`. |
| `0x9B` | `0x2387` | `0x57D49` | `0x0066` | `DreamLink connection error`; TAB changes directory, CAN exits. |
| `0x9C` | `0x23EF` | `0x57DB1` | `0x0069` | `DreamLink is not connected`; TAB changes directory, CAN exits. |
| `0x9E` | `0x24BE` | `0x57E80` | `0x0072` | `Error <detail> received from DreamLink Host`; TAB changes directory, CAN exits. |

## Current Bottom

For the FILE menu layer, the user-visible handlers are now resolved down to:

- C688 resource/picker/name-entry helpers for `RECALL`, `STORE`, `DELETE`,
  `RENAME`, and `INITIALIZE`.
- `DC98:455F` for the `COPY` direction selector and multi-select list.
- Existing lower storage docs for the DOS-like file API, endpoint map, format
  path, and copy transfer internals.

The COMMUNICATE `SEND FILE` and `RECEIVE FILE` wrappers reuse this
picker/name-entry scaffolding around `C688:7F5A`, `C688:8005`, `C688:811D`, and
`C688:7E3E`; those communication app handlers are expanded separately in
[`wp-communicate-handlers.md`](wp-communicate-handlers.md).
