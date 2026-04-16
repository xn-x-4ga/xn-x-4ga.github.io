#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
import frontmatter
import datetime
import sys
import tomllib
from concurrent.futures import ThreadPoolExecutor
from jinja2 import Environment, FileSystemLoader
from markdown_it import MarkdownIt
from mdit_py_plugins.footnote import footnote_plugin
from pathlib import Path
from pygments import highlight
from pygments.lexers import get_lexer_by_name, TextLexer
from pygments.formatters import HtmlFormatter

def highlight_code(code, lang, attrs):
	try:
		lexer = get_lexer_by_name(lang)
	except Exception:
		lexer = TextLexer()
	formatter = HtmlFormatter(cssclass="highlight")
	return highlight(code, lexer, formatter)

class BlogGenerator:
	def __init__(self):
		config_path = Path("config.toml")
		if not config_path.exists():
			print("❌ Error: No se encontró config.toml.")
			sys.exit(1)

		with open(config_path, "rb") as f:
			raw_config = tomllib.load(f)

		lang_str = raw_config["lang"]

		site_url = raw_config["site_url"].rstrip('/') + '/'
		raw_path = raw_config["base_path"].strip('/')

		if raw_path:
			full_base_url = f"{site_url}{raw_path}/"
			base_path_for_links = f"/{raw_path}"
		else:
			full_base_url = site_url
			base_path_for_links = ""

		self.config = {
			'site_name': raw_config["site_name"],
			'site_url': site_url,
			'base_path': base_path_for_links,
			'base_url': full_base_url,
			'lang': lang_str,
			'settings': {
				'posts_per_page': raw_config["posts_per_page"]
			}
		}

		self.dest_dir = Path(".")
		self.posts_dir = Path("_contents")
		self.templates_dir = Path("_templates")

		self.setup_markdown_and_templates()



	def setup_markdown_and_templates(self):
		self.md = (
			MarkdownIt("commonmark", {"highlight": highlight_code})
			.enable("table")
			.use(footnote_plugin)
		)

		if not self.templates_dir.exists():
			print(f"❌ Error: Directorio de plantillas no encontrado: {self.templates_dir}")
			sys.exit(1)

		self.env = Environment(loader=FileSystemLoader(self.templates_dir))
		try:
			self.template_base = self.env.get_template('base.html')
			self.template_lists = self.env.get_template('lists.html')
		except Exception as e:
			print(f"❌ Error cargando plantillas Jinja2: {e}")
			sys.exit(1)

		self.template_sitemap = self.load_optional_template('sitemap.xml')
		self.template_rss = self.load_optional_template('rss.xml')

	def load_optional_template(self, name):
		try:
			return self.env.get_template(name)
		except Exception:
			return None

	@staticmethod
	def _parse_date(raw_date):
		dt = None
		if raw_date:
			if isinstance(raw_date, str):
				try:
					dt = datetime.datetime.fromisoformat(raw_date)
				except ValueError:
					dt = None
			elif isinstance(raw_date, datetime.date) and not isinstance(raw_date, datetime.datetime):
				dt = datetime.datetime.combine(raw_date, datetime.time.min)
			else:
				dt = raw_date
		return dt.astimezone() if dt else None

	def process_md(self, file_path):
		mtime = file_path.stat().st_mtime
		post = frontmatter.load(file_path)
		content = post.content
		data = {k: v for k, v in post.metadata.items() if v is not None}

		data.update({
			'slug': file_path.stem,
			'url': f"{file_path.stem}.html",
			'mtime': mtime,
			'lang': data.get('lang', self.config['lang'])
		})

		data['date'] = self._parse_date(data.get('date'))
		rendered_html = self.md.render(content)
		data['content'] = rendered_html
		data['has_code'] = 'class="highlight"' in rendered_html

		return data

	def generate_paginated_list(self, posts_list, folder_path, base_name, title_prefix, base_rel_path='', is_taxonomy=False, folder_name="", is_index=False):
		per_page = self.config['settings']['posts_per_page']
		total_pages = (len(posts_list) + per_page - 1) // per_page
		if not posts_list: return

		for i in range(total_pages):
			page_posts = posts_list[i * per_page : (i + 1) * per_page]
			filename = f"{base_name}.html" if i == 0 else f"{base_name}{i:02d}.html"

			with open(folder_path / filename, 'w', encoding='utf-8') as f:
				f.write(self.template_lists.render(
					config=self.config,
					title=title_prefix,
					folder_name=folder_name,
					page_posts=page_posts,
					total_pages=total_pages,
					current_page=i,
					base_name=base_name,
					base_path=base_rel_path,
					is_taxonomy=is_taxonomy,
					is_index=is_index,
					has_code=False,
					current_url=f"{self.config['base_url']}{folder_name + '/' if folder_name else ''}{filename}",
					now=datetime.datetime.now()
				))

	def generate(self):
		start = time.time()
		posts = []
		tax_maps = {'categoría': {}, 'tag': {}}

		global_mtime = Path(__file__).stat().st_mtime
		if self.templates_dir.exists():
			for t_file in self.templates_dir.rglob('*'):
				if t_file.is_file():
					global_mtime = max(global_mtime, t_file.stat().st_mtime)

		if self.posts_dir.exists():
			md_files = list(self.posts_dir.glob('*.md'))
			with ThreadPoolExecutor() as executor:
				results = executor.map(self.process_md, md_files)

			for data in results:
				posts.append(data)
				if data.get('category'):
					tax_maps['categoría'].setdefault(data['category'], []).append(data)
				if data.get('tags'):
					for tag in data['tags']:
						tax_maps['tag'].setdefault(tag, []).append(data)

		posts.sort(key=lambda x: x['date'] or datetime.datetime.min.replace(tzinfo=datetime.timezone.utc), reverse=True)

		for p in posts:
			target_path = self.dest_dir / p['url']
			if target_path.exists():
				if target_path.stat().st_mtime > p['mtime'] and target_path.stat().st_mtime > global_mtime:
					continue 

			with open(target_path, 'w', encoding='utf-8') as f:
				f.write(self.template_base.render(
					config=self.config,
					**p,
					base_path='',
					now=datetime.datetime.now(),
					current_url=f"{self.config['base_url']}{p['url']}"
				))

		for folder, mapping in tax_maps.items():
			folder_path = self.dest_dir / folder
			folder_path.mkdir(exist_ok=True)
			for name, p_list in mapping.items():
				p_list.sort(key=lambda x: x['date'] or datetime.datetime.min.replace(tzinfo=datetime.timezone.utc), reverse=True)
				safe_name = name.lower().replace(' ', '_')
				self.generate_paginated_list(
					posts_list=p_list,
					folder_path=folder_path,
					base_name=safe_name,
					title_prefix=name,
					folder_name=folder,
					base_rel_path='../',
					is_taxonomy=True
				)

		self.generate_paginated_list(posts, self.dest_dir, "index", "Entradas Recientes", is_index=True)

		if self.template_sitemap:
			with open(self.dest_dir / 'sitemap.xml', 'w', encoding='utf-8') as f:
				f.write(self.template_sitemap.render(config=self.config, posts=posts, now=datetime.datetime.now()))

		if self.template_rss:
			with open(self.dest_dir / 'rss.xml', 'w', encoding='utf-8') as f:
				f.write(self.template_rss.render(config=self.config, posts=posts, now=datetime.datetime.now()))

		elapsed = time.time() - start
		site_name = self.config.get('site_name', 'Sitio')
		num_posts, num_cats = len(posts), len(tax_maps['categoría'])
		num_tags = len(tax_maps['tag'])

		def plural(count, singular, plural_word):
			return singular if count == 1 else plural_word

		print(f"🚀 {site_name} generado en {elapsed:.2f}s. {num_posts} {plural(num_posts, 'post', 'posts')}, {num_cats} {plural(num_cats, 'categoría', 'categorías')} y {num_tags} {plural(num_tags, 'etiqueta', 'etiquetas')}.")

def main():
	BlogGenerator().generate()

if __name__ == "__main__":
	main()
