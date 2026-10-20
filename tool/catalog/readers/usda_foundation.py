"""USDA Foundation foods (analysed, newest values): see fdc.py."""

from readers.fdc import read_set


def read(data):
    yield from read_set(data, "usda_foundation")
