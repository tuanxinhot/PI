'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const MARKDOWN_DIR = './resources/Assets/plugin_markdown';
const MarkDown = require('./resources/js/showdown.min.js');
const PlugInConfig = require('./plugin_config.js');
const Utils = require('./utils.js');

class PlugInConfigUi {

    // Loads and converts plug-in specific markdown files to HTML format
    static getInfo(pluginName) {
        const converter = new MarkDown.Converter();
        return converter.makeHtml(fs.readFileSync(`${MARKDOWN_DIR}/${pluginName}.md`, 'utf-8',
            e => { if (e) console.error(e); }));
    }

    /**
     * Returns the rendered HTML of the Settings page for the given plug-in.
     * @param {string} pluginName 
     * @param {number} flowindex 
     */
    static getHtml(pluginName, flowindex) {
        // Get the raw yaml values
        const definition = PlugInConfig.getConfigDefinition(pluginName);
        const config = PlugInConfig.getConfig(pluginName, flowindex);

        let rows = '';

        // For each section of the raw YAML config variable, generate HTML
        definition.forEach(node => rows += gen(node));

        return rows;


        // This function parses the YAML config variable recursively to render HTML
        function gen(node, level = 0) {

            // This part is used to make appropriately spaced arrows depicting the level structure, if there is no level provided, nothing will happen
            let arrow = '';
            for (let i = 0; i < level; i++) { arrow += '&nbsp; &nbsp;'; }
            arrow += (level != 0) ? '&#8618; &nbsp;' : '';

            // Declare base HTML for a config item row
            const start = '<div class="flex-container yamlHTMLBaseRow ml-2 mr-2 mb-2">';

            let html = '';
            // If children tag is present that means that this is a multi level config item, continue digging deeper
            if ('children' in node['config_item']) {
                html += start + arrow + genItem(node['config_item']) + '</div>';
                // Recursively call with new level
                node['config_item']['children'].forEach(child_node => html += gen(child_node, level + 1));

                // No children tag present means its at the final level, generate this config item's HTML
            } else {
                html = start + arrow + genItem(node['config_item']) + '</div>';
            }

            return html;
        }

        // This function checks for the type of config item and calls the respective generator functions
        function genItem(item) {
            let html;
            switch (item['datatype']) {
                case 'decimal':
                    html = genDecimal(item);
                    break;
                case 'bool':
                    html = genBool(item);
                    break;
                case 'int':
                    html = genInt(item);
                    break;
                case 'string':
                    html = genString(item);
                    break;
                case 'enum':
                    html = genEnum(item, config);
                    break;
                case 'date':
                    html = genDate(item);
                    break;
                case 'datetime':
                    html = genDateTime(item);
                    break;
                case 'time':
                    html = genTime(item);
                    break;
                case 'display_only':
                    html = genDisplayOnly(item);
                    break;
                case 'network':
                    html = genNetwork(item);
                    break;
                //network interface used must be unit per flow per plugins
                case 'networkperplugin':
                    html = genNetworkPerPlugin(item);
            }
            return html;
        }

        // This is the starting HTML applicable to all config item types
        function genStart(node) {
            const tooltip = ('tooltip' in node) ? '<button id="tooltip" class="mr-2" data-value="' +
                node['tooltip'] + '"><i class="fas fa-info-circle"></i></button>' : ''

            const display_name = ('display_name' in node) ? node['display_name'] + '</div></div>' : '</div>'
            const header = ('display_name' in node) ? '<div class="yamlHTMLConfigItemDisplayName"><div class="mr-2">' :
                '<div style="flex-grow:5">'
            return header + tooltip + display_name;
        }

        // Decimal datatype HTML generator
        // Input type number does not accept decimal point Mottie keyboard input, find out why
        // Until then use text but min max precision parameters are disabled at this stage
        // Change at settings.html too
        function genDecimal(node) {
            let html = genStart(node);
            html += '<div class="yamlHTMLConfigItemTypeContainer mr-2"><input type="text" data-input="float" class="yamlHTMLConfigItemTypeNumber" ';
            let value = parseFloat(config[node['config_name']]);
            if ('min' in node) { html += `min="${node['min']}" `; }
            if ('max' in node) { html += `max="${node['max']}" `; }
            if ('min_length' in node) { html += `minlength="${node['min_length']}" `; }
            if ('max_length' in node) { html += `maxlength="${node['max_length']}" `; }
            if ('precision' in node) {
                let deci = "0.";
                let counter = node['precision'];
                while (counter > 1) {
                    deci += "0";
                    counter -= 1;
                }
                deci += "1";
                html += `step="${deci}" `;
                value = value.toFixed(node['precision'])
            }
            html += `value="${value.toString()}" `;
            html += `data-id="${node['config_name']}" `;
            html += ('unit' in node) ? `/></div><div>${node['unit']}</div>` : '/></div>';
            return html;
        }

        // Boolean datatype HTML generator
        function genBool(node) {
            let html = genStart(node);
            // Special case: class tag is used for css instead of id tag which is the case of other datatype because no multiple ids allowed
            html += `<div class="yamlHTMLConfigItemTypeContainer yamlHTMLConfigItemTypeBool" style="margin-right:20px;"><input  type="radio" style="height:10px; width:10px;" name="${node['config_name']}" value="1" `;
            if (config[node['config_name']]) { html += 'checked '; }
            html += `data-id="${node['config_name']}">True</div>`;
            html += `<div class="yamlHTMLConfigItemTypeBool"><input type="radio" style="height:10px; width:10px;" name="${node['config_name']}" value="0" `;
            if (!config[node['config_name']]) { html += 'checked '; }
            html += `data-id="${node['config_name']}">False</div>`;
            return html;
        }

        // Integer datatype HTML generator
        function genInt(node) {
            let html = genStart(node);
            html += '<div class="yamlHTMLConfigItemTypeContainer mr-2"><input type="number" data-input="integer" class="yamlHTMLConfigItemTypeNumber" ';
            html += `value="${config[node['config_name']]}" `
            if ('min' in node) { html += `min="${node['min']}" `; }
            if ('max' in node) { html += `max="${node['max']}" `; }
            if ('min_length' in node) { html += `minlength="${node['min_length']}" `; }
            if ('max_length' in node) { html += `maxlength="${node['max_length']}" `; }
            if ('regex' in node) { html += `pattern="${node['regex']}" `; }
            html += `data-id="${node['config_name']}"`;
            html += ('unit' in node) ? `/></div><div>${node['unit']}</div>` : '/></div>';
            return html;
        }

        // String datatype HTML generator
        function genString(node) {
            let html = genStart(node);
            html += '<div class="yamlHTMLConfigItemTypeContainer mr-2"><input type="text" data-input="string" class="yamlHTMLConfigItemTypeText" ';
            if ('min_length' in node) { html += `minlength="${node['min_length']}" `; }
            if ('max_length' in node) { html += `maxlength="${node['max_length']}" `; }
            html += 'value="' + config[node['config_name']] + '" ';
            if ('regex' in node) { html += `pattern="${node['regex']}" `; }
            html += `data-id="${node['config_name']}"`;
            html += ('unit' in node) ? `/></div><div>${node['unit']}</div>` : '/></div>';
            return html
        }

        // Enum datatype HTML generator
        function genEnum(node, config) {
            // existingValues = value of other flow
            // Values =  value of current flow with same value datatype
            let existingValues = []
            let values = []
            // If exclusivePerFlow flag detected, that means the value chosen must be unique across flows
            if ('exclusivePerFlow' in node && node['exclusivePerFlow']) {
                existingValues = PlugInConfig.getAllAvailableConfig(pluginName)
                    .map(p => p[node['config_name']])
                    .filter(p => !!p)
            }
            // If exclusivePerPlugin flag detected, that means the value chosen must be unique across flows and accross the plugins with same dataype.
            // other than compare the value accros flow, 
            // we should also compare the value of the plugin with same datatype on different flows too.
            if ('exclusivePerPlugin' in node && node['exclusivePerPlugin']) {
                // get a list of available plugin in both flow, check the data type of each plugin, if it is the same
                // as current target plugin datatype, only filter it out
                // eg: Current plugin is MES with datatype networkperplugin. First we get all plugin values from different flow,
                //     then we compare the plugin dataype with MES, if they are the same, only we filter out the values.
                // !!p is to remove 'null', '', or undefined values.
                values = PlugInConfig.getAvailableConfigperFlows().map(p => {
                    const datatype = JSON.stringify(PlugInConfig.getConfigDefinition(p['plugin']).map(x => x['config_item']['datatype']))
                    const targetDatatype = JSON.stringify(PlugInConfig.getConfigDefinition(pluginName).map(x => x['config_item']['datatype']))
                    if (datatype == targetDatatype) {
                        return p[node['config_name']]
                    }
                }).filter(p => !!p)
            }
            existingValues.push.apply(existingValues, values)
            existingValues = existingValues.filter(item => item != config[node['config_name']])

            let html = genStart(node);
            html += '<div class="yamlHTMLConfigItemTypeContainer"><input type="text" data-toggle="modal" data-target="#modal-plugin-enum" class="yamlHTMLConfigItemTypeText" ';
            html += `value="${config[node['config_name']]}" `;
            html += `data-id="${node['config_name']}" `;

            // Accepts an array of values or the string 'empty', if 'empty' is detected, it skips the population of values
            function genEnumIteration(list, type) {
                html += `data-enum${type}="`;
                if (list != 'empty') {
                    list.forEach((ele, index) => {
                        html += ele;
                        if (index + 1 != list.length) { html += ","; }
                    });
                }
                html += '" '
            }

            if (existingValues.length) { genEnumIteration(existingValues, 'disable') }
            if (node['enum_vals'].length) { genEnumIteration(node['enum_vals'], 'vals') }
            else { genEnumIteration('empty', 'vals') }

            html += '/></div>';
            return html;
        }

        function genTemporal(node, pickertype) {
            let html = genStart(node);
            html += '<div class="yamlHTMLConfigItemTypeContainer"><input type="text" data-toggle="modal" data-target="#modal-plugin-datetime" class="yamlHTMLConfigItemTypeText" ';
            html += `data-pickertype="${pickertype}" `;
            html += `value="${config[node['config_name']]}" `;
            html += `data-id="${node['config_name']}" `;
            html += '/></div>';
            return html;
        }

        // Date datatype HTML generator
        function genDate(node) {
            return genTemporal(node, 'datepicker');
        }

        // Date time datatype HTML generator
        function genDateTime(node) {
            return genTemporal(node, 'datetimepicker');
        }

        // Time datatype HTML generator
        function genTime(node) {
            return genTemporal(node, 'timepicker');
        }

        // Display only datatype HTML generator
        function genDisplayOnly(node) {
            return genStart(node);
        }

        // Queries dynamically and return a selection of network interface values
        function genNetwork(node) {
            node['enum_vals'] = [];
            Utils.getStaticIps().forEach(p => { node['enum_vals'].push(`${p['name']}`) })
            node['exclusivePerFlow'] = true
            return genEnum(node, config)
        }

        function genNetworkPerPlugin(node) {
            node['enum_vals'] = [];
            Utils.getStaticIps().forEach(p => { node['enum_vals'].push(`${p['name']}`) })
            node['exclusivePerFlow'] = true
            node['exclusivePerPlugin'] = true
            return genEnum(node, config)
        }
    }


}

module.exports = PlugInConfigUi;