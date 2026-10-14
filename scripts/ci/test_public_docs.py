#!/usr/bin/env python3
# Shared companions: scripts/ci/check-public-docs.py
"""Regression checks for item identities in the public documentation gate."""

import importlib.util
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('public_docs', Path(__file__).with_name('check-public-docs.py'))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class PublicDocIdentityTests(unittest.TestCase):
    def key(self, source, declaration, kind='a struct field'):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'fixture.rs'
            path.write_text(source)
            start = source.index(declaration)
            message = {
                'message': 'missing documentation for ' + kind,
                'spans': [{'is_primary': True, 'expansion': None, 'file_name': str(path),
                           'byte_start': len(source[:start].encode()),
                           'byte_end': len(source[:start + len(declaration)].encode())}],
            }
            return checker.item_key(message).split('fixture.rs::', 1)[1]

    def test_line_moves_do_not_change_identity(self):
        source = 'pub struct Request { pub endpoint: String }'
        self.assertEqual(self.key(source, 'pub endpoint: String'),
                         self.key('// A comment with { braces } and unicode é\n' + source, 'pub endpoint: String'))

    def test_unrelated_documentation_cannot_offset_a_new_field(self):
        self.assertNotEqual(self.key('pub struct Request { pub endpoint: String }', 'pub endpoint: String'),
                            self.key('pub struct Request { pub timeout: u64 }', 'pub timeout: u64'))

    def test_fields_in_different_structs_have_different_identities(self):
        self.assertNotEqual(self.key('pub struct A { pub value: u64 }', 'pub value: u64'),
                            self.key('pub struct B { pub value: u64 }', 'pub value: u64'))

    def test_enum_variant_fields_have_distinct_namespaces(self):
        self.assertEqual(self.key('pub enum Error { Invalid { value: String } }', 'value: String'),
                         'enum Error/variant Invalid::a struct field::value')

    def test_tuple_variant_fields_have_distinct_namespaces(self):
        self.assertNotEqual(self.key('pub enum Error { A(String) }', 'String'),
                            self.key('pub enum Error { B(String) }', 'String'))

    def test_generic_impl_methods_retain_their_owner(self):
        source = 'impl<T, E> Request<T, E> { pub fn new() -> Self { todo!() } }'
        self.assertIn('Request', self.key(source, 'pub fn new()', 'an associated function'))

    def test_declarations_use_names_instead_of_rust_keywords(self):
        for keyword, kind in [('struct', 'a struct'), ('enum', 'an enum'),
                              ('trait', 'a trait'), ('type', 'a type alias'),
                              ('union', 'a union'), ('mod', 'a module')]:
            left = f'pub {keyword} First {{}}'
            right = f'pub {keyword} Second {{}}'
            self.assertNotEqual(self.key(left, left, kind), self.key(right, right, kind))
        source = 'pub static mut COUNTER: u64 = 0;'
        self.assertTrue(self.key(source, source, 'a static').endswith('::COUNTER'))
        source = 'macro_rules! exported { () => {} }'
        self.assertTrue(self.key(source, source, 'a macro').endswith('::exported'))

    def test_const_methods_use_the_method_name(self):
        source = 'impl Request { pub const fn with_sort() -> Self { todo!() } }'
        self.assertTrue(self.key(source, 'pub const fn with_sort()', 'a method').endswith('::with_sort'))

    def test_literal_braces_and_nested_comments_do_not_change_scopes(self):
        source = 'const X: &str = r#"{fake}"#; /* outer /* {nested} */ end */ pub struct Real { pub value: u64 }'
        self.assertEqual(self.key(source, 'pub value: u64'), 'struct Real::a struct field::value')


class PublicDocCliTests(unittest.TestCase):
    def test_caller_baseline_is_explicit_and_debt_cannot_be_offset(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = 'pub struct Request { pub endpoint: String }'
            (root / 'source.rs').write_text(source)
            declaration = 'pub endpoint: String'
            start = source.index(declaration)
            message = {
                'message': 'missing documentation for a struct field',
                'code': {'code': 'missing_docs'},
                'spans': [{'is_primary': True, 'expansion': None,
                           'file_name': 'source.rs', 'byte_start': start,
                           'byte_end': start + len(declaration)}],
            }
            diagnostics = root / 'diagnostics.jsonl'
            diagnostics.write_text(json.dumps({'message': message}) + '\n')
            baseline = root / 'baseline.json'
            command = [sys.executable, str(Path(__file__).with_name('check-public-docs.py')),
                       str(diagnostics), str(baseline)]
            result = subprocess.run(command + ['--write-baseline'], cwd=root, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            admitted = baseline.read_bytes()
            self.assertEqual(subprocess.run(command, cwd=root, capture_output=True).returncode, 0)
            baseline.write_text(json.dumps(['unrelated documented item']))
            before = baseline.read_bytes()
            result = subprocess.run(command, cwd=root, capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(b'newly undocumented item', result.stderr)
            self.assertIn(b'remove resolved baseline item', result.stderr)
            self.assertEqual(baseline.read_bytes(), before)
            baseline.write_bytes(admitted)
            diagnostics.write_text('')
            result = subprocess.run(command, cwd=root, capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(b'remove resolved baseline item', result.stderr)
            diagnostics.write_text('{incomplete')
            result = subprocess.run(command + ['--write-baseline'], cwd=root, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(baseline.read_bytes(), admitted)

    def test_multiplicity_and_expanded_items_remain_distinct(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = 'pub struct A { pub value: u64 }'
            path = root / 'source.rs'
            path.write_text(source)
            start = source.index('pub value')
            message = {
                'message': 'missing documentation for a struct field',
                'code': {'code': 'missing_docs'},
                'spans': [{'is_primary': True, 'expansion': None,
                           'file_name': str(path), 'byte_start': start,
                           'byte_end': start + len('pub value: u64')}],
            }
            record = json.dumps({'message': message}) + '\n'
            diagnostics = root / 'diagnostics.jsonl'
            diagnostics.write_text(record * 2)
            counts = checker.missing_items(diagnostics)
            self.assertEqual(list(counts.values()), [2])
            message['spans'][0]['expansion'] = {'macro_decl_name': 'fixture!'}
            with self.assertRaises(ValueError):
                checker.item_key(message)


if __name__ == '__main__':
    unittest.main()
