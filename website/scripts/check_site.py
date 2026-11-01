"""Validate built Pages output offline; no network, writes, or third-party parser."""
from html.parser import HTMLParser
from pathlib import Path
import sys
from urllib.parse import unquote, urljoin, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from check_repository import sensitive_content, sensitive_path

BASE = "/invade.io/"
ORIGIN = "https://macarronesc.github.io"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.errors = []
        self.h1_count = 0
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append("Duplicate ID: " + attrs["id"])
            self.ids.add(attrs["id"])
        if tag == "h1":
            self.h1_count += 1
        if tag == "img" and "alt" not in attrs:
            self.errors.append("Image without alt text")
        if tag in {"a", "link", "script", "img", "source"}:
            for name in ("href", "src"):
                if attrs.get(name):
                    self.links.append((attrs[name], tag == "a"))
            for image in attrs.get("srcset", "").split(","):
                if image.strip():
                    self.links.append((image.split()[0], False))


def page_url(path, root):
    relative = path.relative_to(root).as_posix()
    return ORIGIN + BASE + relative.removesuffix("index.html")


def validate(root, policy=None):
    root = root.resolve()
    errors = []
    pages = {path: Page(path.read_text()) for path in root.rglob("*.html")}
    if not pages:
        errors.append("No built HTML pages")
    for file in root.rglob("*"):
        if file.is_symlink() or any(part in {"node_modules", ".git", ".github", "src", "scripts", "tests"} for part in file.relative_to(root).parts):
            errors.append(f"Development path in output: {file}")
        if sensitive_path(file.relative_to(root).as_posix()) or file.suffix in {".md", ".ts", ".gd", ".cfg"}:
            errors.append(f"Private/source file in output: {file}")
        if file.is_file() and sensitive_content(file.read_bytes()):
            errors.append(f"Sensitive material in output: {file}")
    for file, page in pages.items():
        errors.extend(f"{file.relative_to(root)}: {message}" for message in page.errors)
        if page.h1_count != 1:
            errors.append(f"{file.relative_to(root)}: expected one H1, found {page.h1_count}")
        for link, check_anchor in page.links:
            url = urlsplit(urljoin(page_url(file, root), link))
            if url.scheme not in {"https", "http", "mailto", "tel", "data"}:
                errors.append(f"{file.relative_to(root)}: unsupported URL {link}")
                continue
            if url.netloc != "macarronesc.github.io":
                continue
            if not url.path.startswith(BASE):
                errors.append(f"{file.relative_to(root)}: URL outside project base: {link}")
                continue
            target = (root / unquote(url.path[len(BASE):])).resolve()
            if not target.is_relative_to(root):
                errors.append(f"{file.relative_to(root)}: path escapes output: {link}")
                continue
            if target.is_dir():
                target /= "index.html"
            if not target.is_file():
                errors.append(f"{file.relative_to(root)}: missing target {link}")
            elif check_anchor and url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                errors.append(f"{file.relative_to(root)}: missing anchor {link}")
    if policy is not None:
        output_policy = root / "privacy-policy.html"
        if not output_policy.is_file() or output_policy.read_bytes() != policy.read_bytes():
            errors.append("The public policy must match its canonical source byte-for-byte")
    return errors, len(pages)


if __name__ == "__main__":
    web = Path(__file__).resolve().parents[1]
    errors, count = validate(web / "dist", web.parent / "docs/privacy-policy.html")
    for error in errors:
        print(error)
    print(f"Static output: {count} HTML pages, {len(errors)} errors")
    raise SystemExit(bool(errors))
