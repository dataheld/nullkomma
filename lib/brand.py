"""Render optional brand footer facts into each builder's native containers."""

from html import escape
from pathlib import Path
import sys

import yaml


def render(brand, privacy_href, legacy_footer):
    footer = brand.get("defaults", {}).get("nullkomma", {}).get("footer")
    if footer is None:
        if not legacy_footer:
            return None, ""
        html = Path(legacy_footer).read_text().replace("<footer", "<div").replace("</footer>", "</div>")
        if privacy_href:
            html = html.replace('href="/privacy.html"', f'href="{escape(privacy_href, quote=True)}"')
        return html, html
    if not isinstance(footer, dict):
        raise ValueError("defaults.nullkomma.footer must be a mapping")

    meta = brand["meta"]
    destinations = meta["link"]

    def link(item):
        if item.get("privacy"):
            return privacy_href
        return destinations[item["link"]]

    def anchor(text, href):
        return f'<a href="{escape(href, quote=True)}">{escape(text)}</a>'

    left = anchor(meta["name"], destinations["home"])
    if footer.get("tagline"):
        left += " · " + escape(footer["tagline"])
    center = [
        {"text": item["text"], "href": href}
        for item in footer.get("links", [])
        if (href := link(item))
    ]
    right = [
        {"icon": item["icon"], "href": link(item), "aria-label": item["text"]}
        for item in footer.get("social", [])
    ]
    html = "\n".join(f"<p>{text}</p>" for text in [
        left,
        " · ".join(anchor(item["text"], item["href"]) for item in center),
        " · ".join(anchor(item["aria-label"], item["href"]) for item in right),
    ] if text)
    return {"border": True, "left": left, "center": center, "right": right}, html


def main():
    brand_path, legacy_footer, privacy_href, docs_path, output = sys.argv[1:]
    brand = yaml.safe_load(Path(brand_path).read_text()) if brand_path else {}
    footer, html = render(brand, privacy_href, legacy_footer)
    metadata = {}
    if brand_path:
        metadata = {
            "website": {"navbar": {"background": "primary"}},
            "format": {"html": {
                "theme": {
                    "light": ["default", "brand"],
                    "dark": ["default", "brand", "_extensions/nullkomma-brand/dark.scss"],
                },
                "respect-user-color-scheme": True,
                "filters": ["_extensions/nullkomma-brand/landmarks.lua"],
            }},
        }
    if footer is not None:
        metadata.setdefault("website", {})["page-footer"] = footer
    output = Path(output)
    output.mkdir()
    (output / "footer.html").write_text(html)
    (output / "quarto.yml").write_text(yaml.safe_dump(metadata, allow_unicode=True, sort_keys=False))

    docs = yaml.safe_load(Path(docs_path).read_text())
    if metadata:
        website = metadata.get("website", {})
        docs["website"]["navbar"].update(website.get("navbar", {}))
        if "page-footer" in website:
            docs["website"]["page-footer"] = website["page-footer"]
        docs["format"]["html"].update(metadata.get("format", {}).get("html", {}))
        docs["format"]["html"]["theme"]["dark"][-1] = "../nullkomma-brand/dark.scss"
        docs["format"]["html"]["filters"] = ["../nullkomma-brand/landmarks.lua"]
    extension = {
        "title": "nullkomma documentation",
        "version": "0.1.0",
        "contributes": {"project": docs},
    }
    (output / "_extension.yml").write_text(yaml.safe_dump(extension, allow_unicode=True, sort_keys=False))


if __name__ == "__main__":
    main()
