module Jekyll
  class DateSortGenerator < Generator
    priority :low
    safe true

    def generate(site)
      site.data["yearly"] = {}
      site.posts.docs.each.group_by { |post| post.date.year }.each do |y, l|
        site.data["yearly"][y] = l
      end
    end
  end
end
