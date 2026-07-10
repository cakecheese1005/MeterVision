"""
AI Classification Labels.
These values are stored in the database.
"""

AI_OK_DIGITAL = "OK_DIGITAL"
AI_OK_ELECTRO = "OK_ELECTRO"

AI_BLUR_DIGITAL = "BLUR_DIGITAL"
AI_BLUR_ELECTRO = "BLUR_ELECTRO"

AI_REFLECTION_DIGITAL = "REFLECTION_DIGITAL"

AI_MISMATCH_DIGITAL = "MISMATCH_DIGITAL"
AI_MISMATCH_ELECTRO = "MISMATCH_ELECTRO"

AI_IRRELEVANT_DIGITAL = "IRRELEVANT_DIGITAL"
AI_IRRELEVANT_ELECTRO = "IRRELEVANT_ELECTRO"

AI_CLASSES = [
    AI_OK_DIGITAL,
    AI_OK_ELECTRO,
    AI_BLUR_DIGITAL,
    AI_BLUR_ELECTRO,
    AI_REFLECTION_DIGITAL,
    AI_MISMATCH_DIGITAL,
    AI_MISMATCH_ELECTRO,
    AI_IRRELEVANT_DIGITAL,
    AI_IRRELEVANT_ELECTRO,
]

AI_CLASS_DISPLAY = {

    AI_OK_DIGITAL:
        "Image Okay Digital Meter",

    AI_OK_ELECTRO:
        "Image Okay Electro Mechanical Meter",

    AI_BLUR_DIGITAL:
        "Blur Image Digital Meter",

    AI_BLUR_ELECTRO:
        "Blur Image Electro Mechanical Meter",

    AI_REFLECTION_DIGITAL:
        "Reflection Digital Meter",

    AI_MISMATCH_DIGITAL:
        "Reading Mismatch Digital Meter",

    AI_MISMATCH_ELECTRO:
        "Reading Mismatch Electro Mechanical Meter",

    AI_IRRELEVANT_DIGITAL:
        "Irrelevant Image Digital Meter",

    AI_IRRELEVANT_ELECTRO:
        "Irrelevant Image Electro Mechanical Meter",
}