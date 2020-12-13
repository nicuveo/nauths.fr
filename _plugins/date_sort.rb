module Jekyll
  class DateSortGenerator < Generator
    priority :low
    safe true

    def generate(site)
      site.data["yearly"] = {}
      site.categories.each do |lang, pages|
        site.data["yearly"][lang] = []
        pages.each.group_by { |p| p.date.year }.each do |y, l|
          object = {
            "year"  => y,
            "count" => l.size,
            "pages" => l
          }
          site.data["yearly"][lang] += [object]
        end
      end
    end
  end
end
