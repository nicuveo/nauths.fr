module UniDateFilter
  def uni_date(input)
    input.strftime("%Y-%m-%d")
  end
end

Liquid::Template.register_filter(UniDateFilter)
