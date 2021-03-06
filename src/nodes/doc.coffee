Node      = require './node'

marked = require 'marked'
_      = require 'underscore'
_.str  = require 'underscore.string'

# A documentation node is responsible for parsing
# the comments for known tags.
#
module.exports = class Doc extends Node

  # Construct a documentation
  #
  # @param [Object] node the comment node
  # @param [Object] options the parser options
  #
  constructor: (@node, @options) ->
    try
      if @node
        @parseTags @node.comment.split '\n'

    catch error
      console.warn('Create doc error:', @node, error) if @options.verbose

  # Parse the given lines and adds the result
  # to the result object.
  #
  # @param [Array<String>] lines the lines to parse
  #
  parseTags: (lines) ->
    comment = []

    while (line = lines.shift()) isnt undefined

      # Look ahead
      unless /^@example|@overload|@method/.exec line
        while /^\s{2}\w+/.test(lines[0])
          line += lines.shift().substring(1)

      if returnValue = /^@return\s+\[(.+?)\](?:\s+(.+))?/i.exec line
        @returnValue =
          type: returnValue[1]
          desc: returnValue[2]

      else if param = /^@param\s+\(see ((?:[$A-Za-z_\x7f-\uffff][$.\w\x7f-\uffff]*)?[#.][$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*)\)/i.exec line
        @params or= []
        @params.push
          reference: param[1]

      else if param = /^@param\s+([$A-Za-z_\x7f-\uffff][$.\w\x7f-\uffff]*)\s+\(see ((?:[$A-Za-z_\x7f-\uffff][$.\w\x7f-\uffff]*)?[#.][$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*)\)/i.exec line
        @params or= []
        @params.push
          name: param[1]
          reference: param[2]

      else if param = /^@param\s+([^ ]+)\s+\[(.+?)\](?:\s+(.+))?/i.exec line
        @params or= []
        @params.push
          type: param[2]
          name: param[1]
          desc: param[3] or ''

      else if param = /^@param\s+\[(.+?)\]\s+([^ ]+)(?:\s+(.+))?/i.exec line
        @params or= []
        @params.push
          type: param[1]
          name: param[2]
          desc: param[3] or ''

      else if option = /^@option\s+([^ ]+)\s+\[(.+?)\]\s+([^ ]+)(?:\s+(.+))?/i.exec line
        @paramsOptions or= {}
        @paramsOptions[option[1]] or= []

        @paramsOptions[option[1]].push
          type: option[2]
          name: option[3]
          desc: option[4] or ''

      else if see = /^@see\s+([^\s]+)(?:\s+(.+))?/i.exec line
        @see or= []
        @see.push
          reference: see[1]
          label: see[2]

      else if author = /^@author\s+(.+)/i.exec line
        @authors or= []
        @authors.push author[1]

      else if copyright = /^@copyright\s+(.+)/i.exec line
        @copyright = copyright[1]

      else if note = /^@note\s+(.+)/i.exec line
        @notes or= []
        @notes.push note[1]

      else if todo = /^@todo\s+(.+)/i.exec line
        @todos or= []
        @todos.push todo[1]

      else if example = /^@example(?:\s+(.+))?/i.exec line
        title = example[1] || ''
        code = []

        while /^\s{2}.*/.test(lines[0])
          code.push lines.shift().substring(2)

        if code.length isnt 0
          @examples or= []
          @examples.push
            title: title
            code: code.join '\n'

      else if abstract = /^@abstract(?:\s+(.+))?/i.exec line
        @abstract = abstract[1] || ''

      else if /^@private/.exec line
        @private = true

      else if since = /^@since\s+(.+)/i.exec line
        @since = since[1]

      else if version = /^@version\s+(.+)/i.exec line
        @version = version[1]

      else if deprecated = /^@deprecated\s+(.*)/i.exec line
        @deprecated = deprecated[1]

      else if mixin = /^@mixin/i.exec line
        @mixin = true

      else if concern = /^@concern\s+(.+)/i.exec line
        @concerns or= []
        @concerns.push concern[1]

      else if include = /^@include\s+(.+)/i.exec line
        @includeMixins or= []
        @includeMixins.push include[1]

      else if extend = /^@extend\s+(.+)/i.exec line
        @extendMixins or= []
        @extendMixins.push extend[1]

      else if overload = /^@overload\s+(.+)/i.exec line
        signature = overload[1]
        innerComment = []

        while /^\s{2}.*/.test(lines[0])
          innerComment.push lines.shift().substring(2)

        if innerComment.length isnt 0
          @overloads or= []

          doc = {}
          @parseTags.call doc, innerComment

          @overloads.push
            signature: signature.replace(/([$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*)(.+)/, (str, name, params) -> "<strong>#{ name }</strong>#{ params }")
            comment: doc.comment
            summary: doc.summary
            params: doc.params
            options: doc.options
            returnValue: doc.returnValue

      else if method = /^@method\s+(.+)/i.exec line
        signature = method[1]
        innerComment = []

        while /^\s{2}.*/.test(lines[0])
          innerComment.push lines.shift().substring(2)

        if innerComment.length isnt 0
          @methods or= []

          doc = {}
          @parseTags.call doc, innerComment

          @methods.push
            signature: signature
            comment: doc.comment
            summary: doc.summary
            params: doc.params
            options: doc.options
            private: doc.private
            abstract: doc.abstract
            deprecated: doc.deprecated
            version: doc.version
            since: doc.since
            see: doc.see
            returnValue: doc.returnValue
            notes: doc.notes
            todos: doc.todos
            examples: doc.examples
            authors: doc.authors

      else
        comment.push line

    text = comment.join('\n')
    @summary = _.str.clean(/((?:.|\n)*?\.[\s$])/.exec(text)?[1] || text)
    @comment = marked(text).replace /\n+/g, ' '

  # Get a JSON representation of the object
  #
  # @return [Object] the JSON object
  #
  toJSON: ->
    if @node
      json =
        includes: @includeMixins
        extends: @extendMixins
        concerns: @concerns
        abstract: @abstract
        private: @private
        deprecated: @deprecated
        version: @version
        since: @since
        examples: @examples
        todos: @todos
        notes: @notes
        authors: @authors
        copyright: @copyright
        comment: @comment
        summary: @summary
        params: @params
        options: @paramsOptions
        see: @see
        returnValue: @returnValue
        overloads: @overloads
        methods: @methods

      json
