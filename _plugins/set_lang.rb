module SetLangFilter
  def set_lang(input, newlang)
    input.sub(%r{^/../}, "/#{newlang}/")
  end
end

Liquid::Template.register_filter(SetLangFilter)
