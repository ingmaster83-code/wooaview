require 'json'

module Jekyll
  class ViewPageGenerator < Generator
    safe true
    priority :normal

    def generate(site)
      views = site.data['views']
      return unless views&.any?

      Jekyll.logger.info "ViewGenerator:", "#{views.size}개 페이지 생성 중..."

      views.each do |view|
        same_region = views
          .select { |s| s['region'] == view['region'] && s['slug'] != view['slug'] }
          .first(8)
          .map { |s| { 'slug' => s['slug'], 'name' => s['viewName'], 'city' => s['city'], 'typeLabel' => s['typeLabel'], 'typeIcon' => s['typeIcon'], 'image' => s['image'] } }

        same_type = views
          .select { |s| s['type'] == view['type'] && s['slug'] != view['slug'] }
          .first(8)
          .map { |s| { 'slug' => s['slug'], 'name' => s['viewName'], 'region' => s['region'], 'city' => s['city'], 'image' => s['image'] } }

        region_ordered = views
          .select { |s| s['region'] == view['region'] }
          .sort_by { |s| s['viewName'].to_s }
        idx = region_ordered.index { |s| s['slug'] == view['slug'] }
        prev_view = nil
        next_view = nil
        if idx && region_ordered.size > 1
          p = region_ordered[(idx - 1) % region_ordered.size]
          n = region_ordered[(idx + 1) % region_ordered.size]
          prev_view = { 'slug' => p['slug'], 'name' => p['viewName'] }
          next_view = { 'slug' => n['slug'], 'name' => n['viewName'] }
        end

        site.pages << ViewPage.new(site, view, same_region, same_type, prev_view, next_view)
      end

      by_region = views.group_by { |s| s['region'] }
      by_region.each do |region, region_views|
        slug = region_views.first['regionSlug']
        site.pages << RegionPage.new(site, region, slug, region_views)
      end

      by_type = views.group_by { |s| s['type'] }
      by_type.each do |type_key, type_views|
        site.pages << TypePage.new(site, type_key, type_views)
      end

      site.pages << SearchIndexPage.new(site, views)

      Jekyll.logger.info "ViewGenerator:", "완료 (#{views.size}개)"
    end
  end

  class ViewPage < Page
    def initialize(site, view, same_region, same_type, prev_view, next_view)
      @site = site
      @base = site.source
      @dir  = "view/#{view['slug']}"
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(@base, '_layouts'), 'view.html')
      self.data.merge!(view)
      self.data['layout']      = 'view'
      self.data['same_region'] = same_region
      self.data['same_type']   = same_type
      self.data['prev_view']   = prev_view
      self.data['next_view']   = next_view

      self.data['title'] = "#{view['viewName']} 위치·이용시간 | #{view['region']} #{view['city']} #{view['typeLabel']}"
      overview_short = (view['overview'] || '').to_s
      overview_short = overview_short[0, 80] unless overview_short.empty?
      self.data['description'] = "#{view['viewName']}(#{view['region']} #{view['city']}) #{view['typeLabel']} 정보. #{overview_short}"
    end
  end

  class RegionPage < Page
    def initialize(site, region, slug, views)
      @site = site
      @base = site.source
      @dir  = "region/#{slug}"
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(@base, '_layouts'), 'region.html')
      self.data['layout']      = 'region'
      self.data['region']      = region
      self.data['region_slug'] = slug
      self.data['views']       = views
      self.data['title']       = "#{region} 전망대·스카이워크 총정리 | #{views.size}곳"
      self.data['description'] = "#{region} 전망대·스카이워크 #{views.size}곳 총정리! 위치와 소개를 한눈에 확인하세요."
    end
  end

  class TypePage < Page
    def initialize(site, type_key, views)
      @site = site
      @base = site.source
      @dir  = "type/#{type_key}"
      @name = 'index.html'

      label = views.first['typeLabel']
      icon = views.first['typeIcon']

      self.process(@name)
      self.read_yaml(File.join(@base, '_layouts'), 'type.html')
      self.data['layout']     = 'type'
      self.data['type_key']   = type_key
      self.data['type_label'] = label
      self.data['type_icon']  = icon
      self.data['views']      = views
      self.data['title']       = "전국 #{label} 목록 #{views.size}곳"
      self.data['description'] = "전국 #{label} #{views.size}곳 목록. 지역별 정보를 확인하세요."
    end
  end

  class SearchIndexPage < Page
    def initialize(site, views)
      @site = site
      @base = site.source
      @dir  = ''
      @name = 'search_index.json'

      self.process(@name)
      self.data = { 'layout' => nil, 'sitemap' => false }

      index = views.map do |s|
        {
          'slug' => s['slug'], 'name' => s['viewName'], 'region' => s['region'], 'city' => s['city'],
          'typeLabel' => s['typeLabel'], 'image' => s['image'],
        }
      end

      self.content = index.to_json
    end

    def output   = self.content
    def render(layouts, registers); end
  end
end
