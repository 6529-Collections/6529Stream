"""Policy-scoped entity declarations. An unselected collision has no veto."""

from dataclasses import dataclass
import re

from .canonical import MuseumError

KINDS = frozenset(("abstract_work", "visual_content", "information_object", "token", "digital_object",
                   "physical_object", "realization", "person", "group", "place", "event", "statement", "set"))


@dataclass(frozen=True)
class EntityDeclaration:
    identifier: str
    kind: str
    source_record_hash: str
    source_pointer: str
    declaring_agent: str


def entity_index(declarations: tuple[EntityDeclaration, ...],
                 selected_selectors: dict[tuple[str, str], str], references: tuple[str, ...],
                 external_entities: frozenset[str] = frozenset()):
    """Map exact selectors to their admitted agents after the authority check.

    Reuse across selected declarations needs a later explicit continuation
    policy. In its absence, ambiguity rejects irrespective of input order.
    """
    selected = {}
    collisions = []
    for declaration in declarations:
        key = (declaration.source_record_hash, declaration.source_pointer)
        if key not in selected_selectors:
            collisions.append(declaration)
            continue
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9+.-]*:[^\s]+", declaration.identifier):
            raise MuseumError("entity requires an absolute IRI")
        if declaration.declaring_agent != selected_selectors[key]:
            raise MuseumError("entity declaring agent not admitted")
        if declaration.kind not in KINDS:
            raise MuseumError("unsupported selected entity kind")
        previous = selected.get(declaration.identifier)
        if previous:
            raise MuseumError("ambiguous selected identity declaration")
        selected[declaration.identifier] = declaration
    for reference in references:
        if reference not in selected and reference not in external_entities:
            raise MuseumError("unresolved entity reference")
    if selected.keys() & external_entities:
        raise MuseumError("entity cannot be both local and external")
    return tuple(selected[k] for k in sorted(selected)), tuple(collisions)


def require_ordinary_revision_identity(previous: EntityDeclaration, current: EntityDeclaration):
    if previous.identifier != current.identifier or previous.kind != current.kind:
        raise MuseumError("ordinary revision replaced stable identity")
