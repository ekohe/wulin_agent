# frozen_string_literal: true

module WulinAgent
  class AstParamExtractor
    def initialize(controller_class, method_name)
      @controller_class = controller_class
      @method_name = method_name.to_sym
    end

    def to_schema
      node = ast_for_method
      return empty_schema unless node

      properties = {}
      required = []

      each_params_access(node) do |key, ancestors|
        properties[key] = infer_property(ancestors)
        required << key unless optional?(ancestors)
      end

      {properties: properties, required: required.uniq }
    end

    private

    def empty_schema
      {properties: {}, required: []}
    end

    def ast_for_method
      method = @controller_class.instance_method(@method_name)
      file, _line = method.source_location

      if file.nil?
        raise ArgumentError,
          "no Ruby source for #{@controller_class.name}##{@method_name} (owner: #{method.owner})"
      end

      
      tree = RubyVM::AbstractSyntaxTree.parse_file(file)
      find_defn(tree, @method_name)
    end

    def find_defn(node, name)
      return node if node.type == :DEFN && node.children.first == name

      node.children.each do |child|
        next unless child.is_a?(RubyVM::AbstractSyntaxTree::Node)

        found = find_defn(child, name)
        return found if found
      end

      nil
    end

    def each_params_access(node, ancestors = [], &block)
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      key = params_key_from_node(node)
      yield key, ancestors if key

      node.children.each do |child|
        next unless child.is_a?(RubyVM::AbstractSyntaxTree::Node)

        each_params_access(child, ancestors + [node], &block)
      end
    end

    def params_key_from_node(node)
      return unless node.type == :CALL
      return unless node.children[1] == :[]

      receiver = node.children[0]
      return unless params_receiver?(receiver)

      key_node = node.children[2]&.children&.first
      return unless key_node&.type == :SYM || key_node&.type == :LIT

      key_node.children.first
    end

    def params_receiver?(node)
      node.type == :VCALL && node.children.first == :params
    end

    def infer_property(ancestors)
      type = infer_base_type(ancestors)
      if type == "array" && array_of_integers?(ancestors)
        {type: "array", items: {type: "integer"}}
      else
        {type: type}
      end
    end

    def infer_base_type(ancestors)
      ancestors.reverse_each do |node|
        return "integer" if call_method(node) == :to_i
        return "string" if call_method(node) == :to_s
        return "array" if call_method(node) == :split
        return "array" if node.type == :FCALL && node.children.first == :Array
        return "integer" if call_method(node) == :find
      end

      "string"
    end

    def array_of_integers?(ancestors)
      ancestors.any? { |node| call_method(node) == :map }
    end

    def optional?(ancestors)
      ancestors.any? { |node| node.type == :OR }
    end

    def call_method(node)
      node.type == :CALL ? node.children[1] : nil
    end
  end
end
