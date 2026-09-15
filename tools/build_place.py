#!/usr/bin/env python3
"""Build a Roblox Studio-ready .rbxlx place from the src/ tree.

Reads every .luau file under src/ following Rojo naming conventions and emits
an XML place (Egg-Heist.rbxlx, repo root) with all scripts in the right services,
plus a safe fallback baseplate + spawn. The original world model
(assets/world/EggHeistWorld.rbxm) is NOT modified; the game auto-detects
it at runtime (see WorldService).

Usage: python3 tools/build_place.py
"""
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

_ref_counter = 0


def new_ref() -> str:
    global _ref_counter
    ref = f"RBX{_ref_counter}"
    _ref_counter += 1
    return ref


def xml_string(name: str, value: str) -> str:
    return f'<string name="{escape(name)}">{escape(value)}</string>'


def xml_protected(name: str, value: str) -> str:
    return f'<ProtectedString name="{escape(name)}">{escape(value)}</ProtectedString>'


def xml_bool(name: str, value: bool) -> str:
    return f'<bool name="{escape(name)}">{"true" if value else "false"}</bool>'


def xml_float(name: str, value: float) -> str:
    return f'<float name="{escape(name)}">{value!r}</float>'


def xml_int(name: str, value: int) -> str:
    return f'<int name="{escape(name)}">{int(value)}</int>'


def xml_vector3(name: str, x: float, y: float, z: float) -> str:
    return (
        f'<Vector3 name="{escape(name)}">'
        f"<X>{x!r}</X><Y>{y!r}</Y><Z>{z!r}</Z></Vector3>"
    )


def xml_color3(name: str, r: float, g: float, b: float) -> str:
    return (
        f'<Color3 name="{escape(name)}">'
        f"<R>{r!r}</R><G>{g!r}</G><B>{b!r}</B></Color3>"
    )


def xml_cframe(name: str, pos, rot=None) -> str:
    rot = rot or (1, 0, 0, 0, 1, 0, 0, 0, 1)
    tags = "".join(
        f"<{label}>{value!r}</{label}>"
        for label, value in zip(
            ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"), rot
        )
    )
    return (
        f'<CoordinateFrame name="{escape(name)}">'
        f"<X>{pos[0]!r}</X><Y>{pos[1]!r}</Y><Z>{pos[2]!r}</Z>{tags}</CoordinateFrame>"
    )


class Item:
    def __init__(self, class_name: str, properties: str = "", children=None):
        self.class_name = class_name
        self.referent = new_ref()
        self.properties = properties
        self.children = children or []

    def to_xml(self, indent: int = 1) -> str:
        pad = "\t" * indent
        lines = [f'{pad}<Item class="{self.class_name}" referent="{self.referent}">']
        lines.append(f"{pad}\t<Properties>")
        if self.properties:
            for line in self.properties.strip().split("\n"):
                lines.append(f"{pad}\t\t{line.strip()}")
        lines.append(f"{pad}\t</Properties>")
        for child in self.children:
            lines.append(child.to_xml(indent + 1))
        lines.append(f"{pad}</Item>")
        return "\n".join(lines)


# ----------------------------------------------------------------------------
# src/ tree -> instances (Rojo conventions)
# ----------------------------------------------------------------------------


def instance_for_file(path: Path) -> Item | None:
    name = path.name
    source = path.read_text(encoding="utf-8")
    props = xml_string("Name", "") + "\n"  # placeholder, replaced below
    if name.endswith(".server.luau"):
        inst_name = name[: -len(".server.luau")]
        props = (
            xml_string("Name", inst_name)
            + "\n"
            + xml_bool("Disabled", False)
            + "\n"
            + xml_protected("Source", source)
        )
        return Item("Script", props)
    if name.endswith(".client.luau"):
        inst_name = name[: -len(".client.luau")]
        props = (
            xml_string("Name", inst_name)
            + "\n"
            + xml_bool("Disabled", False)
            + "\n"
            + xml_protected("Source", source)
        )
        return Item("LocalScript", props)
    if name.endswith(".luau"):
        inst_name = name[: -len(".luau")]
        props = xml_string("Name", inst_name) + "\n" + xml_protected("Source", source)
        return Item("ModuleScript", props)
    return None


def instance_for_dir(path: Path) -> Item:
    """A directory becomes a Folder, except when it contains an init.* file
    (then it becomes the script instance with the directory's children)."""
    folder_name = path.name
    children: list[Item] = []
    init_source = None
    init_class = None

    for child in sorted(path.iterdir(), key=lambda p: p.name):
        if child.is_file() and child.suffix == ".luau":
            if child.name in ("init.luau", "init.server.luau", "init.client.luau"):
                init_source = child.read_text(encoding="utf-8")
                if child.name == "init.server.luau":
                    init_class = "Script"
                elif child.name == "init.client.luau":
                    init_class = "LocalScript"
                else:
                    init_class = "ModuleScript"
            else:
                item = instance_for_file(child)
                if item:
                    children.append(item)
        elif child.is_dir():
            children.append(instance_for_dir(child))

    if init_class and init_source is not None:
        if init_class == "ModuleScript":
            props = xml_string("Name", folder_name) + "\n" + xml_protected(
                "Source", init_source
            )
        else:
            props = (
                xml_string("Name", folder_name)
                + "\n"
                + xml_bool("Disabled", False)
                + "\n"
                + xml_protected("Source", init_source)
            )
        return Item(init_class, props, children)
    return Item("Folder", xml_string("Name", folder_name), children)


# ----------------------------------------------------------------------------
# place assembly
# ----------------------------------------------------------------------------


def make_spawn_and_baseplate() -> list[Item]:
    baseplate = Item(
        "Part",
        "\n".join(
            [
                xml_string("Name", "Baseplate"),
                xml_bool("Anchored", True),
                xml_bool("CanCollide", True),
                xml_cframe("CFrame", (0, -6, 0)),
                xml_vector3("Size", 600, 2, 600),
                xml_color3("Color", 0.24, 0.35, 0.24),
                xml_float("Transparency", 0),
            ]
        ),
    )
    spawn = Item(
        "SpawnLocation",
        "\n".join(
            [
                xml_string("Name", "SpawnLocation"),
                xml_bool("Anchored", True),
                xml_bool("CanCollide", True),
                xml_bool("Enabled", True),
                xml_bool("Neutral", True),
                xml_bool("AllowTeamChangeOnTouch", False),
                xml_int("Duration", 0),
                xml_cframe("CFrame", (0, 2, 0)),
                xml_vector3("Size", 8, 2, 8),
                xml_color3("Color", 0.35, 0.78, 0.47),
                xml_float("Transparency", 0),
            ]
        ),
    )
    return [baseplate, spawn]


def service_dir(name: str) -> Item | None:
    path = SRC / name
    if not path.is_dir():
        return None
    children = []
    for child in sorted(path.iterdir(), key=lambda p: p.name):
        if child.is_dir():
            children.append(instance_for_dir(child))
        elif child.is_file() and child.suffix == ".luau":
            item = instance_for_file(child)
            if item:
                children.append(item)
    return children


def build() -> str:
    parts = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<roblox version=\"4\">",
        '<Meta name="ExplicitAutoJoints">true</Meta>',
        "<External>null</External>",
        "<External>nil</External>",
    ]

    # Workspace (+ fallback geometry; WorldService repositions/extends at runtime)
    workspace_children = make_spawn_and_baseplate()
    extra = service_dir("Workspace")
    if extra:
        workspace_children.extend(extra)
    workspace_props = "\n".join(
        [
            xml_string("Name", "Workspace"),
            xml_bool("FilteringEnabled", True),
            xml_float("Gravity", 196.2),
        ]
    )
    parts.append(Item("Workspace", workspace_props, workspace_children).to_xml())

    # Lighting
    lighting_props = "\n".join(
        [
            xml_string("Name", "Lighting"),
            xml_float("ClockTime", 14.0),
            xml_float("Brightness", 2.0),
            xml_color3("Ambient", 100 / 255, 100 / 255, 100 / 255),
            xml_color3("OutdoorAmbient", 120 / 255, 120 / 255, 120 / 255),
        ]
    )
    parts.append(Item("Lighting", lighting_props).to_xml())

    # ReplicatedStorage
    rs_children = service_dir("ReplicatedStorage") or []
    parts.append(
        Item("ReplicatedStorage", xml_string("Name", "ReplicatedStorage"), rs_children).to_xml()
    )

    # ServerScriptService
    sss_children = service_dir("ServerScriptService") or []
    parts.append(
        Item(
            "ServerScriptService",
            xml_string("Name", "ServerScriptService"),
            sss_children,
        ).to_xml()
    )

    # StarterPlayer > StarterPlayerScripts / StarterCharacterScripts
    sp_children: list[Item] = []
    starter_player_dir = SRC / "StarterPlayer"
    if starter_player_dir.is_dir():
        for sub in sorted(starter_player_dir.iterdir(), key=lambda p: p.name):
            if sub.is_dir() and sub.name in ("StarterPlayerScripts", "StarterCharacterScripts"):
                kids: list[Item] = []
                for child in sorted(sub.iterdir(), key=lambda p: p.name):
                    if child.is_dir():
                        kids.append(instance_for_dir(child))
                    elif child.is_file() and child.suffix == ".luau":
                        item = instance_for_file(child)
                        if item:
                            kids.append(item)
                sp_children.append(Item(sub.name, xml_string("Name", sub.name), kids))
    if not any(c.class_name == "StarterPlayerScripts" for c in sp_children):
        sp_children.append(
            Item("StarterPlayerScripts", xml_string("Name", "StarterPlayerScripts"))
        )
    parts.append(
        Item("StarterPlayer", xml_string("Name", "StarterPlayer"), sp_children).to_xml()
    )

    # StarterGui (from src/StarterGui when present; UI is code-built by default,
    # so this is usually empty - Screens modules construct the ScreenGuis at runtime)
    sg_children = service_dir("StarterGui") or []
    parts.append(
        Item("StarterGui", xml_string("Name", "StarterGui"), sg_children).to_xml()
    )

    # ServerStorage (from src/ServerStorage when present; reserved for
    # server-only binary assets - none needed yet, everything is procedural)
    ss_children = service_dir("ServerStorage") or []
    parts.append(
        Item("ServerStorage", xml_string("Name", "ServerStorage"), ss_children).to_xml()
    )

    # SoundService / Teams (empty but present)
    parts.append(Item("SoundService", xml_string("Name", "SoundService")).to_xml())
    parts.append(Item("Teams", xml_string("Name", "Teams")).to_xml())

    parts.append("</roblox>")
    return "\n".join(parts) + "\n"


def main() -> int:
    place_xml = build()
    out = ROOT / "Egg-Heist.rbxlx"
    out.write_text(place_xml, encoding="utf-8")
    print(f"Wrote {out} ({len(place_xml):,} bytes, {_ref_counter} instances)")

    # The world model ships in assets/ (byte-identical, never modified);
    # just verify it is present so the zip/place never goes out alone.
    world_src = ROOT / "assets" / "world" / "EggHeistWorld.rbxm"
    if world_src.exists():
        print(f"World model present ({world_src.stat().st_size:,} bytes, unchanged)")
    else:
        print("WARNING: world model not found!", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
