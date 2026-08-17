#!/usr/bin/env python3
"""Regenerate test/form.pdf, the AcroForm fixture used by the form-field tests.

The generated PDF is checked in, so running this is only necessary when the
fixture needs to change. `invariant=1` plus a fixed title keeps the bytes
deterministic, so a no-op regeneration produces no diff.

    python3 test/gen_form.py

Requires reportlab (developed against 4.5.0). After regenerating, update the
expectations in the "form fields" tests in src/root.zig — in particular the
widget count, which includes one annotation per radio button.
"""

import os

from reportlab.pdfgen import canvas
from reportlab.lib.colors import black, white

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "form.pdf")


def main():
    c = canvas.Canvas(OUT, invariant=1)
    c.setTitle("Registration Form")

    # Plain page content, so text extraction is non-empty independently of the
    # form fields.
    c.setFont("Helvetica", 18)
    c.drawString(72, 720, "Registration Form")

    form = c.acroForm
    common = dict(
        borderColor=black,
        fillColor=white,
        textColor=black,
        forceBorder=True,
    )

    # Filled text field.
    form.textfield(
        name="full_name",
        tooltip="Full name",
        value="Ada Lovelace",
        x=72,
        y=660,
        width=200,
        height=20,
        **common,
    )

    # Empty text field.
    form.textfield(
        name="email",
        tooltip="Email address",
        value="",
        x=72,
        y=620,
        width=200,
        height=20,
        **common,
    )

    # Read-only, filled text field.
    form.textfield(
        name="account_id",
        tooltip="Account ID",
        value="ENO-00042",
        x=72,
        y=580,
        width=200,
        height=20,
        fieldFlags="readOnly",
        **common,
    )

    # Checked and unchecked checkboxes.
    form.checkbox(name="agree_terms", tooltip="Agree to terms", checked=True, x=72, y=540, size=16, **common)
    form.checkbox(name="subscribe", tooltip="Subscribe", checked=False, x=72, y=510, size=16, **common)

    # Radio group: three widget annotations sharing the name "plan".
    for i, (value, selected) in enumerate([("basic", False), ("pro", True), ("team", False)]):
        form.radio(
            name="plan",
            tooltip="Plan",
            value=value,
            selected=selected,
            x=72 + i * 40,
            y=470,
            size=16,
            **common,
        )

    # Combo box.
    form.choice(
        name="country",
        tooltip="Country",
        value="Canada",
        options=["Canada", "United States", "Mexico"],
        x=72,
        y=420,
        width=200,
        height=20,
        **common,
    )

    # Multi-select list box.
    form.listbox(
        name="languages",
        tooltip="Languages",
        value=["Zig"],
        options=["Zig", "C", "Rust"],
        fieldFlags="multiSelect",
        x=72,
        y=350,
        width=200,
        height=50,
        **common,
    )

    # Hidden, filled text field. pdfium draws nothing for it, so a viewer must
    # be able to tell it apart from a visible one via the annotation flags and
    # skip it. Kept last so the indices of every field above stay put.
    form.textfield(
        name="internal_ref",
        tooltip="Internal reference",
        value="DO-NOT-SHOW",
        x=72,
        y=300,
        width=200,
        height=20,
        annotationFlags="hidden",
        **common,
    )

    c.showPage()
    c.save()
    print("wrote", OUT)


if __name__ == "__main__":
    main()
